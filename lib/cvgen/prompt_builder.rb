require 'json'

module Cvgen
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a CV and cover letter tailoring assistant. Your job is to produce a tailored JSON object for a specific job application.

      Hard rules — these are non-negotiable:
      1. Use only facts present in the supplied data.json. Never invent or imply employers, titles, dates, metrics, tools, or qualifications.
      2. You may select, reorder, trim, and rephrase. You may not fabricate.
      3. Mirror the job description's wording where it is truthful, so the same real skill is described in the words the employer used.
      4. If the job wants something not in the record, do NOT paper over it. List it under ats.missing_keywords instead.
      5. Reply with one JSON object only, matching the given schema exactly. No prose, no markdown, no code fences, no explanation.
      6. Use New Zealand English spelling in all generated prose (organisation, optimise, programme, honour, etc.).
      7. experience.context fields are instructions to you about how to frame a role. They are never rendered on the CV.
    PROMPT

    def initialize(data:, job_description:, tailored_schema:, config:)
      @data            = data
      @job_description = job_description
      @tailored_schema = tailored_schema
      @config          = config
    end

    def system_prompt
      SYSTEM_PROMPT
    end

    def user_payload
      <<~PAYLOAD
        ## Candidate data (data.json)

        #{JSON.pretty_generate(@data)}

        ## Job description

        #{@job_description}

        ## Output schema (tailored.json — you must match this exactly)

        #{JSON.pretty_generate(@tailored_schema)}

        ## Constraints

        - Bullets per role: maximum #{@config.bullets_per_role}
        - CV length: up to #{@config.page_cap} pages (NZ norm; senior roles may justify one more)
        - Section order on CV: contact details, professional summary, key skills, work experience, education, certifications, awards/publications if relevant, referees line
        - Date format in prose: "Mar 2021 to Present" or "Mar 2021 to Feb 2023"
        - Do not include photo, date of birth, age, gender, or marital status
        - Always include visa/work rights status from personal.visa_status
        - experience.context fields are framing instructions, not CV content
        - education entries with include_in_cv: false must be omitted
        - ats.missing_keywords must list JD keywords with no honest backing in data.json — never close these gaps by fabricating
        - Reply with the JSON object only. No surrounding text.
      PAYLOAD
    end
  end
end
