# CV & Cover Letter Generator: Build Plan

A command line tool that keeps one master record of your career in `data.json`, reads a job description, and produces a tailored, ATS friendly, NZ format CV and cover letter as PDF.

This document is the build spec. Hand it to Claude Code.

---

## 1. Goal

`data.json` is the single source of truth and never changes. For each job you apply to, the tool reads the job description, selects and rewrites the relevant parts of `data.json` to match it, and renders two PDFs: a CV and a cover letter. Nothing is invented. The tool only ever selects, reorders, and rephrases facts that already exist in `data.json`.

---

## 2. Confirmed decisions

- Language: Ruby
- Output: PDF only
- Tailoring engine: the Claude Code CLI, called in headless mode by the Ruby app

### Key assumption to confirm

"Use Claude Code to do that for me" is read here as: the Ruby app runs the `claude` binary as a subprocess (`claude -p`, headless mode) and that is what does the job specific rewriting. This makes the tool fully automated end to end.

If instead you meant "I will run Claude Code by hand and there is no AI inside the app," then section 7 and 8 get deleted and the tool becomes a pure renderer that takes a hand prepared `tailored.json` and turns it into PDFs. The rest of the plan still holds. Tell Claude Code which reading is correct before it starts.

---

## 3. Architecture at a glance

The pipeline is split into two independent stages. This is the most important design decision in the plan, so it is worth stating up front.

1. **Tailor.** Read `data.json` plus the job description, call Claude Code, get back a `tailored.json` (the trimmed and rewritten content plus a cover letter and an ATS report).
2. **Render.** Take `tailored.json` and produce the PDFs. Pure, fast, deterministic, no network, no AI.

Why split it:

- You can hand edit `tailored.json` before rendering if Claude got a phrase slightly wrong, then re render instantly.
- Re rendering to tweak layout costs nothing and never re calls Claude.
- Rendering can be built and fully tested with zero AI dependency, so the hardest part (a clean ATS PDF) gets nailed first.

`generate` is just `tailor` then `render` in one command for the normal path.

Data flow:

```
data.json ─┐
           ├─► tailor ─► tailored.json ─► render ─► cv.pdf
job.txt  ──┘                                     └─► cover_letter.pdf
```

---

## 4. The master record: data.json

This is a superset. It holds everything you have ever done, with full detail and every metric. The tailoring step picks a subset and rephrases it. You maintain this file by hand over time.

Proposed schema (Claude Code should also write a JSON Schema file for validation):

```json
{
  "personal": {
    "full_name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "+64 21 000 0000",
    "location": "Auckland, New Zealand",
    "linkedin": "linkedin.com/in/janedoe",
    "github": "github.com/janedoe",
    "portfolio": "janedoe.dev",
    "work_rights": "New Zealand Citizen"
  },
  "summary": "A long master summary covering everything. The tailor step will cut this down to 3 or 4 lines aimed at the specific role.",
  "skills": [
    { "category": "Languages", "items": ["Ruby", "Python", "SQL"] },
    { "category": "Frameworks", "items": ["Rails", "Sinatra"] },
    { "category": "Cloud", "items": ["AWS", "Docker"] }
  ],
  "experience": [
    {
      "company": "Acme Ltd",
      "title": "Senior Engineer",
      "location": "Auckland, NZ",
      "start": "2021-03",
      "end": null,
      "current": true,
      "summary": "One line on the role and scope.",
      "achievements": [
        "Full list of every achievement with hard numbers. More than will ever appear on one CV. The tailor step selects and rewrites from here."
      ],
      "tech": ["Ruby", "Rails", "AWS"],
      "tags": ["backend", "leadership", "payments"]
    }
  ],
  "education": [
    {
      "institution": "University of Auckland",
      "qualification": "BSc",
      "field": "Computer Science",
      "start": "2014",
      "end": "2017",
      "details": "Optional honours, GPA, relevant papers."
    }
  ],
  "certifications": [
    { "name": "AWS Solutions Architect", "issuer": "Amazon", "date": "2023", "id": "optional" }
  ],
  "projects": [
    {
      "name": "Open source thing",
      "description": "What it is.",
      "tech": ["Ruby"],
      "link": "github.com/janedoe/thing",
      "achievements": ["Metrics if any."]
    }
  ],
  "referees": "Available on request"
}
```

Notes:

- `referees` can be the string `"Available on request"` or an array of referee objects. NZ employers accept either, and "available on request" is common and keeps personal contacts out of a file you scatter widely.
- `tags` on each experience entry are hints that help the tailor step rank relevance. They never appear on the CV.
- Dates use `YYYY-MM` or `YYYY`. The renderer formats them for display.

---

## 5. The tailored output: tailored.json

This is what Claude Code returns and what the renderer consumes. Claude Code should also write a JSON Schema for it, and the parser must validate against it before rendering.

```json
{
  "cv": {
    "headline": "Senior Ruby Engineer",
    "summary": "Three or four lines, rewritten for this role.",
    "key_skills": ["Ordered by relevance to the job description"],
    "experience": [
      {
        "company": "Acme Ltd",
        "title": "Senior Engineer",
        "location": "Auckland, NZ",
        "start": "2021-03",
        "end": null,
        "current": true,
        "bullets": ["Selected and rewritten achievements, strongest first, capped per role"]
      }
    ],
    "education": [],
    "certifications": [],
    "projects": []
  },
  "cover_letter": {
    "date": "2026-05-18",
    "recipient": "Hiring Manager",
    "company": "Target Company",
    "role": "Senior Ruby Engineer",
    "paragraphs": ["Opening", "Body matching your experience to their needs", "Close"],
    "sign_off": "Kind regards,\nJane Doe"
  },
  "ats": {
    "matched_keywords": ["keywords from the JD that genuinely appear in your record"],
    "missing_keywords": ["JD keywords with no honest backing in data.json"],
    "match_score": 78
  }
}
```

The `ats` block is a feature, not decoration. `missing_keywords` is an honest gap report. The prompt must forbid closing those gaps by inventing experience. It is there so you know what the job wants that you cannot truthfully claim, which is genuinely useful before you apply.

---

## 6. Claude Code integration (verified against current docs)

Source checked: the Claude Code headless docs at code.claude.com/docs/en/headless and the docs map at docs.anthropic.com/en/docs/claude-code.

The Ruby app calls the `claude` binary as a subprocess using `Open3`. Confirmed behaviour:

- `claude -p "PROMPT"` runs non interactively (`-p` is short for `--print`). Each invocation is independent with no conversation history, which is exactly what we want.
- `--output-format json` makes Claude return a structured envelope, not loose text. The envelope looks like:

```json
{
  "type": "result",
  "subtype": "success",
  "result": "the assistant's textual answer goes here as a string",
  "session_id": "abc123",
  "total_cost_usd": 0.001,
  "duration_ms": 1234,
  "num_turns": 1
}
```

- `--append-system-prompt "..."` adds instructions on top of Claude Code's defaults. Use this for the role and the hard rules.
- You can pipe stdin into it, for example `cat payload | claude -p ...`. Long prompts should go through stdin rather than a shell argument to avoid length and escaping problems.

Important double parse detail: with `--output-format json` the envelope's `result` field is itself a string. Our prompt asks Claude to make that string be strict JSON matching the `tailored.json` schema. So the flow is: run the subprocess, parse the outer envelope, take `result`, strip any stray code fences defensively, then parse `result` again into the tailored object, then schema validate it.

Recommended invocation shape (Claude Code can refine flags at build time):

```
claude -p \
  --output-format json \
  --append-system-prompt "<role and hard rules>" \
  < payload.txt
```

where `payload.txt` is the full task: the `data.json` contents, the job description, the target `tailored.json` schema, and the instruction to reply with that JSON only.

Capture `total_cost_usd` from the envelope and print it after a run so you can see what each application costs.

---

## 7. Prompt design and integrity guardrails

The system prompt (passed via `--append-system-prompt`) sets the role and the non negotiable rules. The user prompt (stdin) carries the data.

Hard rules to bake into the system prompt:

- Use only facts present in the supplied `data.json`. Never invent or imply employers, titles, dates, metrics, tools, or qualifications.
- You may select, reorder, trim, and rephrase. You may not fabricate.
- Mirror the job description's wording where it is truthful, so the same real skill is described in the words the employer used.
- If the job wants something not in the record, do not paper over it. List it under `ats.missing_keywords`.
- Reply with one JSON object only, matching the given schema. No prose, no markdown, no code fences.

In the user prompt include: the full `data.json`, the full job description, the `tailored.json` JSON Schema, the per role bullet cap (default 5), the target CV length in pages (default up to 2, NZ norm), and the NZ and ATS conventions from sections 9 and 10 so the rewrite respects them.

Build a small retry: if the returned text does not parse as JSON or fails schema validation, retry once with an appended "Your previous reply was not valid JSON against the schema. Reply with the corrected JSON only." On a second failure, stop, save the raw output to `output/last_failure.txt`, and exit with a clear message rather than rendering garbage.

---

## 8. NZ CV format rules

These go into both the prompt (so content fits) and the renderer (so layout fits).

- No photo. No date of birth, age, gender, or marital status. These are normal to omit in NZ and including them can work against you.
- Include work rights or residency status. NZ employers expect it. It comes from `personal.work_rights`.
- Reverse chronological work history.
- Two pages is normal and accepted in NZ. Do not crush everything onto one page. Up to three is fine for senior people. Default cap: 2, configurable.
- Section order: contact details, professional summary, key skills, work experience, education, certifications, then referees (line or list).
- New Zealand English spelling in any generated prose (organisation, optimise, programme where appropriate).
- Referees as "Available on request" is acceptable and is the safe default for a file you send widely.

---

## 9. ATS rules and PDF specifics

ATS friendliness is mostly about the PDF being clean, linear, real text. Rules:

- Single column. No multi column layouts, no text boxes, no tables for any content the parser needs to read. Tables and columns are the most common reason ATS misreads a CV.
- Real selectable text only. No text baked into images. No images at all on the CV.
- Standard fonts. Helvetica or Times are built into the PDF engine and are safe. If a Calibri or Arial look is wanted, embed a permissively licensed substitute (for example DejaVu) rather than relying on the reader's fonts.
- Exact, conventional section headings: "Professional Summary", "Key Skills", "Work Experience", "Education", "Certifications", "Referees". Parsers match on these strings.
- Consistent date format throughout, for example "Mar 2021 to Present".
- Put contact details in the body at the top, not in a PDF header or footer. Many parsers ignore headers and footers.
- Simple bullet character, generous margins, 10 to 11 pt body text.
- Set PDF metadata title and author to your name.

Honest limitation to write into the README, not to hide: a PDF produced by a normal Ruby PDF library is untagged. Untagged but clean, single column, real text PDFs are parsed correctly by the large majority of modern ATS, which is why the layout rules above matter so much. If you ever hit an ATS that struggles, the two stage design means a plain text fallback renderer can be added later that reads the same `tailored.json`. You said PDF only, so build PDF only, but the architecture leaves that door open at no cost.

---

## 10. CLI commands

Use Thor for the command structure. Commands:

- `cvgen init`
  Scaffolds `data.json` from a template and writes a starter config. Run once.

- `cvgen validate --data data.json`
  Validates `data.json` against its JSON Schema. Reports the exact path of any problem. No AI, no network.

- `cvgen tailor --data data.json --job job.txt [--company NAME] [--role TITLE] [--out DIR]`
  Creates the job folder (see Per job storage below), calls Claude Code, and writes `tailored.json` plus a copy of the job description and a `meta.json` into that folder. Prints the ATS match score, the matched keywords, the missing keywords, and the run cost. Does not render.

- `cvgen render --from PATH [--cv-only] [--letter-only]`
  Pure renderer. `PATH` is either a `tailored.json` file or a job folder (it then uses the `tailored.json` inside it). Writes `cv.pdf` and `cover_letter.pdf` into that same job folder. No AI, no network. Fast. Re running it just overwrites the two PDFs in place, so you can tweak `tailored.json` and re render freely.

- `cvgen generate --data data.json --job job.txt [...]`
  Convenience command. Runs `tailor` then `render` in one go, all into one job folder. This is the everyday command.

- `cvgen list`
  Lists every stored job application: folder name, company, role, date generated, and ATS score, read from each folder's `meta.json`. This is your application history.

Job description input: accept `--job FILE`, or piped stdin, or a `--job-text "..."` string. Files are the normal case.

### Per job storage

Every job post you process gets its own self contained folder. Nothing is left loose and nothing from a previous application is overwritten by a new one. The folder holds the tailored content, both PDFs, the exact job description that produced them, and a metadata record. This means an application is fully reproducible and reviewable months later.

Folder name: a slug built from company, role, and date, for example `acme-ltd--senior-ruby-engineer--2026-05-18`. Company and role come from `--company` and `--role` when given, otherwise from the parsed job description, otherwise from the job file name as a fallback.

Layout:

```
output/
  acme-ltd--senior-ruby-engineer--2026-05-18/
    job.txt            # exact job description used for this application
    tailored.json      # Claude output, editable, the input to render
    cv.pdf
    cover_letter.pdf
    meta.json          # company, role, date, model, run cost, ATS score,
                        # and a hash of the data.json used, for traceability
  globex--backend-engineer--2026-05-12/
    job.txt
    tailored.json
    cv.pdf
    cover_letter.pdf
    meta.json
  index.json           # one entry per application, appended on each tailor run
```

`index.json` is a simple append only list that `cvgen list` reads, so you do not have to scan folders to see your history.

Collision rule: if a folder with the same slug already exists, do not clobber it. By default create a sibling with a numeric suffix (`...--2026-05-18-2`) so a re run for the same role keeps both versions. `--force` overwrites the existing folder in place. `--out DIR` overrides the whole path if you want a specific location.

`output/` is gitignored in full, since it contains personal data and your live applications.

Exit codes: 0 success, non zero on validation failure, Claude failure, or render failure, so it can be scripted.

---

## 11. Project structure

```
cv-generator/
  bin/
    cvgen                     # executable entry point
  lib/
    cvgen.rb                  # requires
    cvgen/
      cli.rb                  # Thor commands, arg parsing only
      config.rb               # loads .cvgen.yml and env
      data_loader.rb          # read + schema validate data.json
      job_description.rb      # read from file, stdin, or string
      prompt_builder.rb       # builds system prompt + stdin payload
      claude_client.rb        # Open3 wrapper around `claude -p`, retry, envelope parse
      response_parser.rb      # double parse, fence strip, schema validate tailored.json
      pipeline.rb             # orchestrates tailor and render
      renderers/
        base.rb               # shared layout helpers, fonts, spacing
        cv_pdf.rb             # ATS safe CV renderer
        cover_letter_pdf.rb   # cover letter renderer
      schema/
        data.schema.json
        tailored.schema.json
  data/
    data.example.json
  templates/
    data.template.json
  output/                     # gitignored, one folder per job application + index.json
  spec/                       # RSpec
    fixtures/
      data.json
      job.txt
      tailored.json
  Gemfile
  .cvgen.yml.example
  .gitignore                  # ignores data.json, output/, .cvgen.yml
  README.md
```

Keep `cli.rb` thin. It parses arguments and calls `pipeline.rb`. All real logic lives in the named classes so it is testable without invoking the CLI.

---

## 12. Gems

- `thor` for the CLI
- `prawn` for PDF generation. Pure Ruby, no headless browser, produces real text, which is what ATS needs. Avoid `prawn-table` for CV content since tables hurt ATS parsing. Lay the CV out with plain text flow and bounding boxes, not tables.
- `json_schemer` (or `json-schema`) to validate `data.json` and `tailored.json`
- `dotenv` for config and any API or auth env, optional
- stdlib `open3` for the subprocess, `json` for parsing
- `rspec` for tests
- `pdf-reader` for tests only, to extract text from generated PDFs and assert content
- `rubocop` for lint

Pin versions in the Gemfile.

---

## 13. Error handling and edge cases

Handle each of these explicitly with a clear, human readable message:

- `claude` binary not found on PATH. Tell the user the tool needs Claude Code installed and point at the install docs. Do not stack trace.
- Claude returns a non zero exit, an auth error, or a rate limit. Surface the message from stderr plainly.
- Claude reply is not valid JSON, or fails schema validation. Retry once with a corrective instruction, then on second failure save raw output to `output/last_failure.txt` and exit non zero.
- `data.json` missing or invalid. Print the schema error with its JSON path so the user can fix the right field.
- Job description file missing or empty. Refuse early.
- `data.json` so large the prompt is unwieldy. At minimum warn. Optionally allow `tags` and a `--focus` flag to pre filter experience before sending, which keeps the payload tight.
- Font not available. Bundle the embedded font file in the repo so rendering never depends on the host machine's fonts.
- Output directory not writable, or would overwrite. Create it, and either version the folder by date or require `--force` to overwrite.

Determinism note for the README: Claude output varies between runs. That is expected. The two stage split is the mitigation. Once you are happy with a `tailored.json`, you can re render forever without re calling Claude, and you can hand edit it first.

---

## 14. Testing

- Unit tests for `data_loader` (valid and invalid fixtures), `prompt_builder` (asserts the hard rules and schema are present in the prompt), `response_parser` (handles clean JSON, fenced JSON, trailing prose, and schema failures).
- Renderer tests generate a PDF from the fixture `tailored.json`, then use `pdf-reader` to extract text and assert: every expected section heading is present, contact details are in the body, no multi column artifacts, dates formatted consistently, content stays within the page cap.
- `claude_client` is tested with a fake injected command runner so the suite never calls the real Claude and is fast and offline. Inject the runner as a dependency rather than shelling out directly inside the class.
- One real end to end smoke test, skipped by default, gated behind an env flag, for manual confidence.
- RuboCop in CI.

The fixture set (`spec/fixtures/data.json`, `job.txt`, `tailored.json`) is the backbone. Build it first.

---

## 15. Config and privacy

- `.cvgen.yml` holds: Claude binary path, default page cap, default bullets per role, output directory, font choice, NZ English on or off.
- `--flags` override config. Config overrides built in defaults.
- Privacy: `data.json` is personal data and its full contents are sent to Claude Code on every `tailor` run. State this plainly in the README. `.gitignore` must exclude `data.json`, `output/`, and `.cvgen.yml` so personal data and generated applications never get committed.

---

## 16. Phased build order

Build in this order. Each phase is usable on its own, and the AI dependency comes late so the hardest piece (a clean ATS PDF) is proven first.

1. Skeleton: repo, Gemfile, Thor CLI stub, `cvgen init`, config loader, `.gitignore`.
2. `data.json` JSON Schema, `data_loader`, `cvgen validate`. Plus the example and template files.
3. The per job storage layer: folder slugging, collision rule, `meta.json`, `index.json`, and `cvgen list`. Build this before the renderer so every later phase writes into the right place from day one.
4. Renderers from a static fixture `tailored.json`. Get `cvgen render` producing a correct NZ format, ATS clean CV and cover letter PDF into a job folder. No AI yet. Spend the most care here and verify with the `pdf-reader` text extraction tests.
5. `tailored.json` schema, `prompt_builder`, `claude_client` (Open3, retry, envelope parse), `response_parser`. Wire `cvgen tailor`, writing `tailored.json`, the `job.txt` copy, and `meta.json` into the job folder.
6. `cvgen generate` end to end. Error handling and the retry path. Cost printout. ATS report printout.
7. Full test suite, RuboCop clean, README including the privacy note and the honest ATS limitation note.

---

## 17. Things for you to confirm before or during the build

- The Claude Code interpretation in section 2. This is the one that changes the architecture, so confirm it first.
- Whether `referees` should default to "Available on request" or hold real referee objects. Recommendation: the string default.
- Page cap. Default is up to 2, which is the NZ norm. Senior roles often justify 3.
- Bullets per role cap. Default 5.
- Whether you want NZ English spelling enforced in generated prose. Default yes.
- Authentication for Claude Code. Headless runs use whatever auth your local Claude Code is already set up with (subscription or API key). The tool itself never handles keys. Worth noting in case you run it somewhere without that setup.

---

## Quick summary for Claude Code

Build a Ruby Thor CLI named `cvgen`. It maintains a static `data.json` master career record, and for each job it reads a job description, shells out to the `claude` binary in headless mode (`claude -p --output-format json --append-system-prompt`, payload via stdin) to produce a tailored `tailored.json` that only ever selects and rephrases facts already in `data.json` and never invents anything, then renders an NZ format, ATS clean CV and cover letter as PDF using Prawn. Every job post gets its own folder under `output/` holding `job.txt`, `tailored.json`, `cv.pdf`, `cover_letter.pdf`, and `meta.json`, with an `index.json` history and a `cvgen list` command. Existing folders are never clobbered. Two stage pipeline: `tailor` (AI, writes the json and metadata) and `render` (pure, writes the PDFs into the same folder), with `generate` running both. Build the storage layer, then the renderer against a fixture, AI last. Honesty about gaps via an `ats` report is a required feature, not optional.
