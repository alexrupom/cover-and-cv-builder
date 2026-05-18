require 'date'
require_relative 'base'

module Cvgen
  module Renderers
    class CoverLetterPdf
      include Base

      def initialize(tailored:, personal:, config:)
        @letter   = tailored['cover_letter']
        @personal = personal
        @config   = config
      end

      def render(output_path)
        pdf = build_doc
        render_header(pdf)
        render_body(pdf)
        render_sign_off(pdf)
        pdf.render_file(output_path)
      end

      def full_name
        @personal['full_name']
      end

      private

      def render_header(pdf)
        pdf.font('Helvetica-Bold', size: BODY_SIZE) do
          pdf.text @personal['full_name']
        end

        pdf.font('Helvetica', size: SMALL_SIZE) do
          contact_parts = [@personal['email'], @personal['phone'], @personal['location']].compact
          pdf.text contact_parts.join('  |  ')
          pdf.text @personal['visa_status'] if @personal['visa_status']
        end

        pdf.move_down SECTION_GAP

        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text @letter['date'] || Date.today.strftime('%-d %B %Y')
        end

        pdf.move_down SECTION_GAP

        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text @letter['recipient'] if @letter['recipient']
          pdf.text @letter['company']   if @letter['company']
        end

        pdf.move_down SECTION_GAP

        pdf.font('Helvetica-Bold', size: BODY_SIZE) do
          pdf.text "Re: #{@letter['role']}"
        end

        pdf.move_down SECTION_GAP
      end

      def render_body(pdf)
        paragraphs = @letter['paragraphs'] || []
        paragraphs.each do |para|
          pdf.font('Helvetica', size: BODY_SIZE) do
            pdf.text para, leading: LINE_GAP
          end
          pdf.move_down SECTION_GAP
        end
      end

      def render_sign_off(pdf)
        pdf.move_down 4
        sign_off = @letter['sign_off'] || "Kind regards,\n#{@personal['full_name']}"
        pdf.font('Helvetica', size: BODY_SIZE) do
          pdf.text sign_off, leading: LINE_GAP
        end
      end
    end
  end
end
