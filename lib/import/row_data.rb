# frozen_string_literal: true

require 'date'
require 'redcarpet'
require 'redcarpet/render_strip'

module Import
  class RowData
    attr_reader :row, :attrs

    def field_values(object, row, attrs, errors = {}, row_num = 0) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      md = Redcarpet::Markdown.new(Redcarpet::Render::StripDown, space_after_headers: true)
      missing_fields_errors, date_errors = Array.new(2) { [] }

      fields = METADATA_FIELDS.select { |f| [:universal, object].include? f[:object] } + FILE_SET_FLAG_FIELDS
      fields.each do |field|
        if row[field[:field_name]].present?
          is_multivalued = field[:multivalued]
          # ensuring all values are arrays
          field_values = split_field_values(row[field[:field_name]], is_multivalued)
          field_values = strip_markdown(field[:field_name], field_values, md)
          field_values = cleanup_open_access(field[:field_name], field_values)
          field_values = downcase_format(field[:field_name], field_values)
          field_values = downcase_role(field[:field_name], field_values)
          field_values = map_doi(field[:field_name], field_values)
          field_values = map_cc_license(field[:field_name], field_values)

          # at this point some bad values may have been removed. This line will need to be changed if we ever start...
          # using true/false values in metadata instead of yes/no, as false will not pass through.
          next if field_values.none?

          if field[:date_format]
            field_values = field_check_dates(field[:field_name], field_values, date_errors)
            next if field_values.blank?
          end
          attrs[field[:metadata_name]] = return_scalar_or_multivalued(field_values, is_multivalued)
        # a cover or FeaturedRepresentative FileSet missing metadata is normal, so don't bother the user in those cases
        elsif field[:required] == true && row[field['Representative Kind']].blank?
          missing_fields_errors << field[:field_name]
        end
      end
      # These checks were designed to check FileSet metadata. We never set, e.g. required fields on Monograph...
      # metadata so don't bother with errors on the Monograph row.
      combine_field_errors(errors, row_num, missing_fields_errors, date_errors) if object == :file_set
    end

    private

      def split_field_values(sheet_value, is_multivalued)
        if is_multivalued == :yes_split
          sheet_value.split(';').map!(&:strip).reject(&:empty?)
        elsif is_multivalued == :yes_multiline
          Array(sheet_value.split(';').map!(&:strip).reject(&:empty?).join("\n"))
        else
          # force array for uniformity, ease of iteration in subsequent methods
          Array.wrap(sheet_value.strip)
        end
      end

      def strip_markdown(field_name, field_values, metadata)
        field_name == "Keywords" ? field_values.map! { |value| metadata.render(value).strip! } : field_values
      end

      # HELIO-3287 only 'yes' values make sense for this Blacklight facet field
      def cleanup_open_access(field_name, field_values)
        return field_values unless field_name == 'Open Access?'
        field_values.map { |val| val.downcase == 'yes' ? 'yes' : nil }
      end

      def map_doi(field_name, field_values)
        return field_values unless field_name == 'DOI'
        field_values.map { |val| val.sub('https', 'http').sub('http://doi.org/', '') }
      end

      def map_cc_license(field_name, field_values)
        return field_values unless field_name == 'CC License'
        field_values.map do |val|
          # `select_all_options` rather than `select_active_options` as, unlike the UI edit forms, we allow all values here
          match = Hyrax::LicenseService.new.select_all_options.find { |license| val.downcase == license[0].downcase }
          match.present? ? match[1] : val
        end
      end

      def downcase_format(field_name, field_values)
        return field_values unless field_name == 'ISBN(s)'
        downcased_output_value = []

        field_values.each do |value|
          downcased_parens_value = value[/\(([^()]*)\)$/]&.downcase
          downcased_output_value << (downcased_parens_value.present? ? value.sub(/\s*\(.+\)$/, '').strip + ' ' + downcased_parens_value : value)
        end

        downcased_output_value.presence
      end

      def downcase_role(field_name, field_values)
        return field_values unless ['Creator(s)', 'Additional Creator(s)'].include? field_name

        field_values = field_values.first.split(/\r?\n/).reject(&:blank?)
        downcased_output_value = []

        field_values.each do |value|
          downcased_parens_value = value[/\(([^()]*)\)$/]&.downcase
          downcased_output_value << (downcased_parens_value.present? ? value.sub(/\s*\(.+\)$/, '').strip + ' ' + downcased_parens_value : value)
        end

        downcased_output_value.present? ? Array(downcased_output_value.join("\n")) : nil
      end

      def return_scalar_or_multivalued(field_values, is_multivalued)
        is_multivalued == :no ? field_values.first : Array.wrap(field_values)
      end

      def field_check_dates(field_name, actual_values, date_errors)
        output_dates = []
        actual_values.each do |actual_value|
          fixed_date = output_date(actual_value)
          if actual_value.present? && actual_value.casecmp('perpetuity') != 0 && fixed_date.blank?
            date_errors << field_name + ': "' + actual_value + '"'
          elsif fixed_date.present?
            output_dates << fixed_date
          end
        end
        output_dates
      end

      def output_date(date_string)
        y = m = d = ''
        date_string.tr!('/', '-')
        if date_string[/\A\d{4}-\d{2}-\d{2}\z/]
          y, m, d = date_string.split '-'
        elsif date_string[/\A\d{4}-\d{2}\z/]
          y, m = date_string.split '-'
          d = '01'
        elsif date_string[/\A\d{4}\z/]
          y = date_string
          m = d = '01'
        end
        return nil unless (y + m + d).length == 8 && Date.valid_date?(y.to_i, m.to_i, d.to_i)
        y + '-' + m + '-' + d
      end

      def combine_field_errors(errors, row_num, missing_fields_errors, date_errors)
        message = ''
        message += missing_fields_errors.empty? ? '' : "\nmissing required fields: \n" + missing_fields_errors.join(', ')
        message += date_errors.empty? ? '' : "\nthese dates cannot be padded to a YYYY-MM-DD value and will be discarded: \n" + date_errors.join(', ')
        message = maybe_hide_errors(message, row_num, missing_fields_errors, date_errors)
        errors[row_num] = message if message.present?
      end

      def maybe_hide_errors(message, row_num, missing_fields_errors, date_errors)
        # silence error data for row 3, which we've been using for the cover
        if row_num == 3 || (missing_fields_errors.empty? && date_errors.empty?)
          ''
        else
          message
        end
      end
  end
end
