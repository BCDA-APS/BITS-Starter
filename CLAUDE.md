# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **BITS-Starter**, a GitHub *template* repo for creating a Bluesky data-acquisition
instrument at the APS, built on the [`apsbits`](https://bcda-aps.github.io/BITS/) framework.
Out of the box `src/` is empty (`src/.gitkeep`) — the real instrument package is **scaffolded**
into `src/` by `create-bits`, not committed here. Expect to be working in generated code that
does not yet exist in a fresh checkout.

When `init_repo.yml` runs on a repo created from this template (any repo other than
`bcda-aps/bits-starter`), `.github/workflows/init_repo.sh` renames the package from
`bits_instrument`/`APSBITS` to the new repo name, strips the template README section, and
deletes itself. This is a one-time, CI-side rename — don't expect it locally.

## Two parallel dependency stacks (know which one you're in)

- **pixi** (`pixi.toml`, conda-forge, this `pixi_compatibility` branch) — the newer path,
  pins exact versions (bluesky 1.14.4, ophyd 1.11.0, Python 3.12) and defines run tasks.
  Linux-only (`platforms = ["linux-64"]`).
- **pip/conda** (`pyproject.toml`, README) — `conda create … python=3.11; pip install apsbits`.
  CI (`code.yml`) uses this path on **Python 3.11**.

These disagree on Python version (3.12 in pixi vs 3.11 in pyproject/CI) and the two are *not*
kept in sync automatically. `pyproject.toml` is the installable package definition; `pixi.toml`
is the dev/run environment + task runner.

## Placeholder names you must replace

`pixi.toml` still contains leftover names from the 11-BM beamline instance it was copied from —
these are **placeholders**, not working references, until a real instrument is scaffolded:
- `bm11_b` / `bm11_b_qserver` in the `[tasks]` (e.g. `start`, `qs_restart`) → should be `<instrument>` / `<instrument>_qserver`
- `11bm-bits = { path = ".", editable = true }` in `[pypi-dependencies]` → your package name
- `qs_start_manager` references `qs-confdig.yml` (typo for `qs-config.yml`)

If a pixi task fails with a missing module/path, suspect one of these stale names first.

## Common commands

```bash
# Environment (pixi): default | dev | doc | all
pixi install                       # solve + create default env
pixi shell -e dev                  # enter dev env (ruff, pytest, mypy, pre-commit)

# Scaffold a new instrument into src/ (creates src/<name>/ and src/<name>_qserver/)
create-bits <instrument_name>
pip install -e .

# Run an interactive acquisition session
pixi run start                     # ipython -i loading <name>.startup (MPLBACKEND=qt5agg)
# or manually:  ipython  ->  from <instrument_name>.startup import *

# Queueserver (host process manages the RunEngine; clients attach to it)
pixi run qs_restart                # = src/<name>_qserver/qs_host.sh restart
pixi run qs_host status            # start|stop|restart|status|checkup|console|run
queue-monitor &                    # GUI client

# Tests — pytest stops on FIRST failure (addopts = -x, importlib import mode)
pytest                             # full suite
pytest path/to/test_x.py::test_name   # single test

# Lint/format — pre-commit runs ruff (lint+fix) and ruff-format; this is the CI gate
pre-commit run --all-files
ruff check --fix . && ruff format .
```

Sim plans to confirm a working install (inside an IPython/Jupyter session after startup):
`RE(sim_print_plan())`, `RE(sim_count_plan())`, `RE(sim_rel_scan_plan())`.

## Generated instrument architecture

`create-bits` produces a package under `src/<instrument>/` (mirroring `apsbits.demo_instrument`):

```
src/<instrument>/
  startup.py            # session bootstrap — the orchestrator (see below)
  configs/
    iconfig.yml         # master data-collection config; feature flags (NeXus, SPEC, catalog…)
    devices.yml         # declarative ophyd device table, loaded by make_devices()
    devices_aps_only.yml# devices loaded ONLY when on the APS subnet
    extra_logging.yml
  devices/              # ophyd Device classes referenced by devices.yml
  plans/                # bluesky plans (incl. the sim_*_plan demos)
  callbacks/            # NeXus / SPEC file writers, custom subscriptions
  suspenders/  utils/
src/<instrument>_qserver/
  qs-config.yml         # queueserver host config
  qs_host.sh            # start/stop/restart the QS host (uses `screen`)
```

**`startup.py` is the control flow** — understanding it is the fastest way to understand the
instrument. In order it: configures logging → `prepare_bits()` → `load_config(configs/iconfig.yml)`
→ `init_instrument()` → builds the RunEngine stack (`init_bec_peaks`, `init_catalog`,
`init_RE(..., subscribers=[bec, cat])`) → conditionally wires NeXus/SPEC writers based on
iconfig flags → loads plans → `make_devices()` reads `devices.yml` (plus `devices_aps_only.yml`
when `host_on_aps_subnet()`) → `setup_baseline_stream()`.

Two cross-cutting behaviors to keep in mind when editing:
- **Context-adaptive imports**: `startup.py` branches on `running_in_queueserver()` — the set of
  imported plans differs between an interactive session and the queueserver. The same package
  must work in IPython console, Jupyter, *and* queueserver.
- **Config-driven, not import-driven**: devices and many plans are wired through YAML
  (`devices.yml`), not Python imports. To add hardware, add an ophyd class in `devices/` and a
  matching entry in `configs/devices.yml` — don't just import it in `startup.py`. (The
  `epics-2-ophyd` skill automates exactly this IOC→device→YAML flow.)

## CI / style notes

- `code.yml`: `lint` job (`pre-commit run --all-files`) must pass before the `test-matrix`
  job runs. Tests install OS Qt/X11 libs + xvfb (this is a PyQt app), use micromamba, and
  currently run **only Python 3.11** (3.12/3.13 commented out, "waiting for upstream packages").
- Active style is **ruff** (line-length 88) via pre-commit, which "replaces Flake8, isort,
  pydocstyle, pyupgrade, Black". The `[tool.black]`/`[tool.flake8]` blocks in `pyproject.toml`
  (line-length 115) are vestigial and not enforced by CI — follow ruff (88).
- Docstrings are linted: ruff selects `D100`–`D107`, so public modules/classes/functions need
  docstrings.
