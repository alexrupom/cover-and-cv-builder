require 'prawn'

module Cvgen
  module Renderers
    module Base
      MARGIN        = 40
      BODY_SIZE     = 10.5
      HEADING_SIZE  = 13
      SUB_SIZE      = 11
      SMALL_SIZE    = 9.5
      LINE_GAP      = 2
      SECTION_GAP   = 10
      BULLET        = '•'.freeze

      FONT_FAMILIES = {
        'helvetica' => {
          normal: 'Helvetica',
          bold: 'Helvetica-Bold',
          italic: 'Helvetica-Oblique',
          bold_italic: 'Helvetica-BoldOblique'
        }
      }.freeze

      def build_doc(page_size: 'A4')
        Prawn::Document.new(
          page_size: page_size,
          page_layout: :portrait,
          margin: MARGIN,
          info: {
            Title: full_name,
            Author: full_name
          }
        )
      end

      def full_name
        raise NotImplementedError
      end

      def format_date(str)
        return 'Present' if str.nil?

        parts = str.to_s.split('-')
        year  = parts[0]
        month = parts[1]
        return year if month.nil?

        month_name = Date::ABBR_MONTHNAMES[month.to_i]
        "#{month_name} #{year}"
      end

      def date_range(start_date, end_date)
        "#{format_date(start_date)} to #{format_date(end_date)}"
      end

      def divider(pdf)
        pdf.stroke_color '999999'
        pdf.stroke_horizontal_rule
        pdf.stroke_color '000000'
        pdf.move_down 6
      end

      def section_heading(pdf, title)
        pdf.move_down SECTION_GAP
        pdf.font('Helvetica-Bold', size: SUB_SIZE) do
          pdf.text title.upcase, character_spacing: 0.5
        end
        divider(pdf)
      end
    end
  end
end
