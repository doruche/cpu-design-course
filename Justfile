set shell := ["bash", "-euo", "pipefail", "-c"]

# List the public repository CLI.
default:
    @just --list

# Check required tools, pinned inputs, and optional Vivado access.
doctor:
    @./scripts/doctor.sh

# Show repository state and the stable build configurations.
status:
    @./scripts/build.sh status

# Print the complete resolved contract for one configuration.
show-config config:
    @./scripts/build.sh show-config "{{ config }}"

# Lint one explicit product/topology configuration.
lint config:
    @./scripts/build.sh lint "{{ config }}"

# Run a named single-module test suite.
unit suite:
    @./scripts/build.sh unit "{{ suite }}"

# Run a named cross-module integration suite.
integration suite:
    @./scripts/build.sh integration "{{ suite }}"

# Run one official Trace case under an explicit configuration.
trace config case:
    @./scripts/build.sh trace "{{ config }}" "{{ case }}"

# Run all official Trace cases serially under an explicit configuration.
trace-all config:
    @./scripts/build.sh trace-all "{{ config }}"

# Run a named CPU-driven system simulation suite.
system suite:
    @./scripts/build.sh system "{{ suite }}"

# Run a named repository verification gate.
gate gate:
    @./scripts/build.sh gate "{{ gate }}"

# Stage or run a canonical Vivado product action.
vivado product action:
    @./scripts/build.sh vivado "{{ product }}" "{{ action }}"

# Export the submission archive using the documented environment variables.
export-submission:
    @./scripts/export-submission.sh

# Remove generated repository and Trace outputs.
clean:
    @./scripts/build.sh clean
