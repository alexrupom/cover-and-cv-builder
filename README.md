# cvgen — CV & Cover Letter Generator

A command-line tool that keeps one master record of your career in `data.json` and produces a tailored, ATS-friendly, NZ-format CV and cover letter as PDF for each job you apply to.

## How it works

1. You maintain `data.json` — a superset of everything you've ever done.
2. For each job, you run `cvgen generate`. It reads the job description, calls Claude (via the `claude` CLI in headless mode), and gets back a tailored selection of your real experience — nothing is invented.
3. Two PDFs are rendered: `cv.pdf` and `cover_letter.pdf`, stored in a dedicated folder under `output/`.

The pipeline has two independent stages so you can re-render instantly without re-calling Claude:

```
data.json ─┐
           ├─► cvgen tailor ─► tailored.json ─► cvgen render ─► cv.pdf
job.txt  ──┘                                                  └─► cover_letter.pdf
```

## Requirements

- Ruby 2.7+
- [Claude Code CLI](https://claude.ai/download) installed and authenticated (`claude --version` should work)
- Bundler (`gem install bundler`)

## Setup

```bash
git clone <this-repo>
cd cover-and-cv-builder
bundle install
cvgen init          # creates data.json and .cvgen.yml from templates
```

Add `bin/` to your PATH or run via `bundle exec bin/cvgen`.

## Commands

### `cvgen init`
Scaffolds `data.json` from the template and creates a starter `.cvgen.yml`. Run once.

### `cvgen validate`
Validates `data.json` against its JSON Schema. Reports the exact path of any problem.

```bash
cvgen validate --data data.json
```

### `cvgen generate` *(everyday command)*
Calls Claude and renders both PDFs in one step.

```bash
# Paste the job description into jobs/, then:
cvgen generate --job jobs/acme-senior-engineer.txt
```

Company name and role are extracted automatically from the job description. Use `--company` and `--role` only if you want to override what Claude infers (affects the output folder name).

Options:
- `--data` — path to `data.json` (default: `data.json` in current directory)
- `--job` — path to a job description file
- `--job-text` — job description as an inline string
- `--company`, `--role` — used for the output folder name; inferred from Claude's output if omitted
- `--out` — override the output directory
- `--force` — overwrite an existing job folder instead of creating a numbered sibling

### `cvgen tailor`
Calls Claude and writes `tailored.json` only — no PDFs yet. Useful if you want to review and edit the tailored content before rendering.

```bash
cvgen tailor --job acme.txt --company "Acme Ltd" --role "Senior Engineer"
```

After reviewing (and optionally editing) `tailored.json`, render with:

```bash
cvgen render --from output/acme-ltd--senior-engineer--2026-05-18/
```

### `cvgen render`
Pure renderer — no AI, no network. Takes a `tailored.json` (or a job folder) and writes the PDFs.

```bash
cvgen render --from output/acme-ltd--senior-engineer--2026-05-18/
cvgen render --from output/acme-ltd--senior-engineer--2026-05-18/ --cv-only
```

### `cvgen list`
Lists every stored job application with ATS score and date.

```bash
cvgen list
```

## Output structure

Every job gets its own self-contained folder:

```
output/
  acme-ltd--senior-engineer--2026-05-18/
    job.txt           # exact job description used
    tailored.json     # Claude's output — editable, re-renderable
    cv.pdf
    cover_letter.pdf
    meta.json         # company, role, date, cost, ATS score, data.json hash
  index.json          # one entry per application
```

## Configuration

Copy `.cvgen.yml.example` to `.cvgen.yml` (done automatically by `cvgen init`) and adjust:

```yaml
claude_bin: claude        # path to the claude binary
page_cap: 2               # maximum CV pages
bullets_per_role: 5       # maximum bullet points per role
nz_english: true          # NZ English spelling in generated prose
output_dir: output        # where job folders are written
font: helvetica           # 'helvetica' (built-in) or path to a TTF file
```

## Privacy

`data.json` contains your full career history and is sent to Claude Code on every `tailor` run. The `.gitignore` excludes `data.json`, `output/`, and `.cvgen.yml` so personal data and generated applications are never committed to git.

## ATS notes

The renderer produces single-column, real-selectable-text PDFs using standard fonts — the layout rules the plan specifies (no tables, no text boxes, contact details in the body) are the main factor in ATS compatibility, not the library. The `ats` block in `tailored.json` gives you an honest gap report: `missing_keywords` lists what the job wants that you cannot truthfully claim, so you know before you apply.

## Development

```bash
bundle exec rspec           # run tests
bundle exec rubocop         # lint
```

Tests never call the real Claude. The `ClaudeClient` accepts an injected runner, and the suite uses a fake one. One smoke test (`spec/smoke/`) can be added later behind an `CVGEN_SMOKE=1` env flag for end-to-end confidence.
