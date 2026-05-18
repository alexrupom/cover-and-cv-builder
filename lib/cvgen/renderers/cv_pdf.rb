require 'date'
require_relative 'base'

module Cvgen
  module Renderers
    class CvPdf
      include Base

      def initialize(tailored:, personal:, config:)
        @cv       = tailored['cv']
        @personal = personal
        @config   = config
      end

      def render(output_path)
        pdf = build_doc
        render_contact(pdf)
        render_summary(pdf)
        render_skills(pdf)
        render_experience(pdf)
        render_education(pdf)
        render_certifications(pdf) if @cv['certifications']&.any?
        render_awards(pdf)         if @cv['awards']&.any?
        render_publications(pdf)   if @cv['publications']&.any?
        render_languages(pdf)      if @cv['languages']&.any?
        render_referees(pdf)
        pdf.render_file(output_path)
      end

      def full_name
        @personal['full_name']
      end

      private

      def render_contact(pdf)
        pdf.font('Helvetica-Bold', size: HEADING_SIZE) do
          pdf.text @personal['full_name'], align: :center
        end
        pdf.move_down 4

        contact_parts = [
          @personal['email'],
          @personal['phone'],
          @personal['location']
        ].compact

        linkedin = @personal['linkedin']
        github   = @personal['github']
        contact_parts << "linkedin.com/in/#{linkedin}" if linkedin
        contact_parts << "github.com/#{github}"        if github

        pdf.font('Helvetica', size: SMALL_SIZE) do
          pdf.text contact_parts.join('  |  '), align: :center
        end
        pdf.move_down 3

        if (visa = @personal['visa_status'])
          pdf.font('Helvetica', size: SMALL_SIZE) do
            pdf.text visa, align: :center
          end
        end
        pdf.move_down 6
      end

      def render_summary(pdf)
        section_heading(pdf, 'Professional Summary')
        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text @cv['summary'], leading: LINE_GAP
        end
      end

      def render_skills(pdf)
        skills = @cv['key_skills']
        return if skills.nil? || skills.empty?

        section_heading(pdf, 'Key Skills')
        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text skills.join('  •  '), leading: LINE_GAP
        end
      end

      def render_experience(pdf)
        entries = @cv['experience']
        return if entries.nil? || entries.empty?

        section_heading(pdf, 'Work Experience')

        entries.each_with_index do |job, idx|
          pdf.move_down 2 if idx.positive?
          render_job(pdf, job)
        end
      end

      def render_job(pdf, job)
        title   = job['title']
        company = job['company']
        loc     = job['location']
        dates   = date_range(job['start_date'], job['end_date'])
        mode    = job['work_mode']

        right_text = [dates, mode].compact.join('  |  ')

        pdf.font('Helvetica-Bold', size: BODY_SIZE) do
          pdf.text_box title, at: [0, pdf.cursor], width: pdf.bounds.width / 2
        end
        pdf.font('Helvetica', size: SMALL_SIZE) do
          pdf.text_box right_text, at: [pdf.bounds.width / 2, pdf.cursor],
                                   width: pdf.bounds.width / 2, align: :right
        end
        pdf.move_down BODY_SIZE + 2

        pdf.font('Helvetica-Oblique', size: SMALL_SIZE) do
          pdf.text [company, loc].compact.join('  —  ')
        end
        pdf.move_down 3

        bullets = job['bullets'] || []
        bullets.each do |bullet|
          pdf.font('Helvetica', size: BODY_SIZE) do
            pdf.text "#{BULLET}  #{bullet}", indent_paragraphs: 12, leading: LINE_GAP
          end
          pdf.move_down 2
        end
      end

      def render_education(pdf)
        entries = @cv['education']
        return if entries.nil? || entries.empty?

        section_heading(pdf, 'Education')

        entries.each_with_index do |edu, idx|
          pdf.move_down 2 if idx.positive?
          dates = date_range(edu['start_date'], edu['end_date'])

          pdf.font('Helvetica-Bold', size: BODY_SIZE) do
            pdf.text_box edu['degree'], at: [0, pdf.cursor], width: pdf.bounds.width * 0.65
          end
          pdf.font('Helvetica', size: SMALL_SIZE) do
            pdf.text_box dates, at: [pdf.bounds.width * 0.65, pdf.cursor],
                                width: pdf.bounds.width * 0.35, align: :right
          end
          pdf.move_down BODY_SIZE + 2

          pdf.font('Helvetica', size: SMALL_SIZE) do
            parts = [edu['institution'], edu['location']].compact
            pdf.text parts.join('  —  ')
          end
        end
      end

      def render_certifications(pdf)
        section_heading(pdf, 'Certifications')
        @cv['certifications'].each do |cert|
          pdf.font('Helvetica', size: BODY_SIZE) do
            line = cert['name']
            line += "  —  #{cert['issuer']}" if cert['issuer']
            line += "  (#{cert['date']})"    if cert['date']
            pdf.text "#{BULLET}  #{line}", indent_paragraphs: 12, leading: LINE_GAP
          end
          pdf.move_down 2
        end
      end

      def render_awards(pdf)
        section_heading(pdf, 'Awards & Recognition')
        @cv['awards'].each do |award|
          pdf.font('Helvetica-Bold', size: BODY_SIZE) do
            pdf.text award['title']
          end
          pdf.font('Helvetica', size: SMALL_SIZE) do
            parts = [award['event'], award['date'] ? format_date(award['date']) : nil,
                     award['location']].compact
            pdf.text parts.join('  |  ')
          end
          pdf.move_down 4
        end
      end

      def render_publications(pdf)
        section_heading(pdf, 'Publications')
        @cv['publications'].each do |pub|
          pdf.font('Helvetica-Bold', size: BODY_SIZE) do
            pdf.text pub['title']
          end
          pdf.font('Helvetica', size: SMALL_SIZE) do
            parts = [pub['venue'], pub['date'] ? format_date(pub['date']) : nil,
                     pub['recognition']].compact
            pdf.text parts.join('  |  ')
          end
          pdf.move_down 4
        end
      end

      def render_languages(pdf)
        section_heading(pdf, 'Languages')
        items = @cv['languages'].map { |l| "#{l['language']} (#{l['proficiency']})" }
        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text items.join('  •  '), leading: LINE_GAP
        end
      end

      def render_referees(pdf)
        section_heading(pdf, 'Referees')
        ref = @personal['references'] || 'Available on request'
        pdf.font('Helvetica', size: BODY_SIZE) do
          if ref.is_a?(Array)
            ref.each do |r|
              pdf.text "#{r['name']}, #{r['title']}, #{r['company']}  |  #{r['email']}"
              pdf.move_down 3
            end
          else
            pdf.text ref.to_s
          end
        end
      end
    end
  end
end
