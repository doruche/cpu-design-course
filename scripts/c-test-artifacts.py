#!/usr/bin/env python3
"""Build the three consumer images from one audited RV32 ELF."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
PROGRAM_HEADER = struct.Struct("<IIIIIIII")
SECTION_HEADER = struct.Struct("<IIIIIIIIII")
PT_LOAD = 1
SHF_ALLOC = 0x2


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(65536), b""):
            value.update(chunk)
    return value.hexdigest()


def tool_line(command: list[str]) -> str:
    result = subprocess.run(command, check=True, text=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    return result.stdout.splitlines()[0]


def parse_elf(path: Path) -> tuple[dict[str, object], list[dict[str, object]]]:
    data = path.read_bytes()
    if len(data) < ELF_HEADER.size:
        raise SystemExit(f"ELF is truncated: {path}")
    fields = ELF_HEADER.unpack_from(data)
    ident = fields[0]
    if ident[:4] != b"\x7fELF" or ident[4] != 1 or ident[5] != 1:
        raise SystemExit("expected a little-endian ELF32 image")

    (_, elf_type, machine, _version, entry, program_offset, section_offset,
     flags, header_size, program_size, program_count, section_size,
     section_count, section_name_index) = fields
    if elf_type != 2 or machine != 243 or entry != 0:
        raise SystemExit(
            f"ELF ABI mismatch: type={elf_type} machine={machine} entry={entry:#x}")
    if flags & 0x1:
        raise SystemExit("ELF advertises compressed RVC instructions")
    if header_size != ELF_HEADER.size or program_size != PROGRAM_HEADER.size:
        raise SystemExit("unsupported ELF32 header layout")

    segments: list[dict[str, object]] = []
    for index in range(program_count):
        offset = program_offset + index * program_size
        ph = PROGRAM_HEADER.unpack_from(data, offset)
        p_type, p_offset, vaddr, paddr, file_size, mem_size, p_flags, align = ph
        if p_type != PT_LOAD:
            continue
        end = paddr + mem_size
        if paddr < 0x0000C800:
            valid = end <= 0x0000C800
            region = "rom"
        elif paddr < 0x00019000:
            valid = end <= 0x00019000
            region = "ram1"
        else:
            valid = False
            region = "outside-load-regions"
        if not valid:
            raise SystemExit(
                f"load segment {index} exceeds its memory region: {paddr:#x}..{end:#x}")
        segments.append({
            "index": index, "region": region, "vaddr": vaddr,
            "paddr": paddr, "file_size": file_size, "memory_size": mem_size,
            "flags": p_flags, "alignment": align, "file_offset": p_offset,
        })

    if section_size != SECTION_HEADER.size or section_count == 0:
        raise SystemExit("unsupported ELF32 section layout")
    raw_sections = [
        SECTION_HEADER.unpack_from(data, section_offset + index * section_size)
        for index in range(section_count)
    ]
    names_header = raw_sections[section_name_index]
    names = data[names_header[4]:names_header[4] + names_header[5]]
    sections: list[dict[str, object]] = []
    for index, sh in enumerate(raw_sections):
        name_offset, sh_type, sh_flags, address, _offset, size, *_rest = sh
        if not sh_flags & SHF_ALLOC:
            continue
        end = names.find(b"\0", name_offset)
        name = names[name_offset:end].decode("ascii")
        sections.append({
            "index": index, "name": name, "type": sh_type,
            "address": address, "size": size, "end": address + size,
        })

    return ({
        "class": "ELF32", "endianness": "little", "machine": "RISC-V",
        "entry": entry, "flags": flags, "segments": segments,
    }, sections)


def parse_coe(path: Path) -> list[int]:
    lines = path.read_text(encoding="ascii").splitlines()
    if lines[:2] != ["memory_initialization_radix=16;",
                     "memory_initialization_vector="]:
        raise SystemExit("COE header mismatch")
    words = []
    for line in lines[2:]:
        token = line.rstrip(",;")
        if not re.fullmatch(r"[0-9A-F]{8}", token):
            raise SystemExit(f"invalid COE word: {line}")
        words.append(int(token, 16))
    if not lines[-1].endswith(";"):
        raise SystemExit("COE vector is not terminated")
    return words


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--student-id", required=True)
    parser.add_argument("--elf", type=Path, required=True)
    parser.add_argument("--raw", type=Path, required=True)
    parser.add_argument("--dump", type=Path, required=True)
    parser.add_argument("--source", type=Path, action="append", default=[])
    args = parser.parse_args()

    root = args.root.resolve()
    prefix = args.elf.with_suffix("")
    coe = prefix.with_suffix(".coe")
    uart = prefix.with_suffix(".uart.bin")
    manifest = prefix.with_suffix(".manifest")

    elf_info, sections = parse_elf(args.elf)
    attributes = subprocess.check_output(
        ["riscv32-unknown-elf-readelf", "-A", str(args.elf)], text=True)
    architecture_match = re.search(r'Tag_RISCV_arch: "([^"]+)"', attributes)
    if not architecture_match:
        raise SystemExit("ELF has no RISC-V architecture attribute")
    architecture = architecture_match.group(1)
    extensions = architecture.split("_")
    if not extensions[0].startswith("rv32i") or not any(
            extension.startswith("m") for extension in extensions[1:]):
        raise SystemExit(f"ELF is not RV32IM: {architecture}")
    forbidden = tuple("afdc")
    if any(extension.startswith(forbidden) for extension in extensions[1:]):
        raise SystemExit(f"ELF uses an unsupported ISA extension: {architecture}")
    elf_info["architecture"] = architecture
    raw = bytearray(args.raw.read_bytes())
    if len(raw) > 0x00019000:
        raise SystemExit(f"raw image exceeds ROM+RAM1: {len(raw):#x}")
    raw.extend(b"\0" * (-len(raw) % 4))
    args.raw.write_bytes(raw)
    words = [value[0] for value in struct.iter_unpack("<I", raw)]

    with coe.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("memory_initialization_radix=16;\n")
        stream.write("memory_initialization_vector=\n")
        for index, word in enumerate(words):
            suffix = ";" if index == len(words) - 1 else ","
            stream.write(f"{word:08X}{suffix}\n")

    with uart.open("wb") as stream:
        stream.write(struct.pack(">I", len(words)))
        for word in words:
            stream.write(struct.pack(">I", word))

    coe_words = parse_coe(coe)
    uart_data = uart.read_bytes()
    uart_count = struct.unpack_from(">I", uart_data)[0]
    uart_words = [value[0] for value in struct.iter_unpack(">I", uart_data[4:])]
    if coe_words != words or uart_count != len(words) or uart_words != words:
        raise SystemExit("raw/COE/UART payload relationship is inconsistent")

    source_paths = [path.resolve() for path in args.source]
    source_hashes = {
        str(path.relative_to(root)): digest(path) for path in source_paths
    }
    source_commit = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    dirty = bool(subprocess.check_output(
        ["git", "-C", str(root), "status", "--porcelain", "--"] +
        [str(path.relative_to(root)) for path in source_paths], text=True).strip())
    candidate = bool(re.fullmatch(r"[0-9]{8,12}", args.student_id))

    artifacts = {}
    for kind, path in (("elf", args.elf), ("dump", args.dump),
                       ("raw_bin", args.raw), ("coe", coe),
                       ("uart_bin", uart)):
        artifacts[kind] = {
            "path": str(path.resolve().relative_to(root)),
            "size": path.stat().st_size,
            "sha256": digest(path),
        }

    document = {
        "schema": 1,
        "program": args.name,
        "identity": {"student_id": args.student_id, "candidate": candidate},
        "source": {
            "commit": source_commit,
            "dirty": dirty,
            "files": source_hashes,
        },
        "toolchain": {
            "gcc": tool_line(["riscv32-unknown-elf-gcc", "--version"]),
            "objcopy": tool_line(["riscv32-unknown-elf-objcopy", "--version"]),
            "objdump": tool_line(["riscv32-unknown-elf-objdump", "--version"]),
        },
        "abi": elf_info,
        "sections": sections,
        "memory_contract": {
            "rom": {"start": 0, "end": 0x0000C800},
            "ram1": {"start": 0x0000C800, "end": 0x00019000},
            "heap_stack": {"start": 0x00019000, "end": 0x00025800},
            "behavioral_memory_minimum_bytes": 0x00025800,
        },
        "payload": {
            "word_count": len(words),
            "raw_byte_order": "little-endian bytes",
            "coe_word_order": "32-bit hexadecimal words",
            "uart_package": "big-endian word-count header plus big-endian words",
            "cross_checked": True,
        },
        "artifacts": artifacts,
    }
    manifest.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    print(f"program-manifest: {manifest.relative_to(root)}")
    print(f"program-candidate: {'yes' if candidate else 'no (development identity)'}")
    print(f"program-payload-words: {len(words)}")


if __name__ == "__main__":
    main()
