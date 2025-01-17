# frozen_string_literal: true

require 'rails_helper'
require 'import/csv_parser'
require 'metadata_fields' unless defined?(MONO_FILENAME_FLAG) # solves loading issue when this spec is run solo

describe Import::CSVParser do
  let(:input_file) { File.join(fixture_path, 'csv', 'import_sections', 'tempest_sections.csv') }
  let(:parser) { described_class.new(input_file) }

  before do
    # Don't print status messages during specs
    allow($stdout).to receive(:puts)
  end

  describe 'initializer' do
    it 'has an input file' do
      expect(parser.file).to eq input_file
    end
  end

  describe '#attributes' do
    subject { parser.attributes }

    it 'collects attributes from the CSV file' do # rubocop:disable RSpec/ExampleLength
      expect(subject['title']).to eq ['The Tempest: A Subtitle']
      expect(subject['identifier']).to eq ['http://www.example.com/handle', '999.999.9999']
      expect(subject['creator']).to eq ["Shakespeare, William\nPlaywright, Mr. Uncredited (editor)"] # role was downcased
      expect(subject['contributor']).to eq ["Christopher Marlowe (illustrator)\nSir Francis Bacon"] # role was downcased
      expect(subject['subject']).to eq ['Dog', 'Cat', 'Mouse']
      expect(subject['isbn']).to eq ['134513451345', '1451-25423 (e-book)', '1451343513'] # format was downcased
      expect(subject['series']).to eq ['Series the First', 'Cereal Series', 'Serial the Third']
      expect(subject['files']).to eq [
        nil,
        'shipwreck.jpg',
        'miranda.jpg',
        nil,
        'ファイル.txt',
        nil,
        'shipwreck1.jpg',
        'miranda1.jpg',
        'shipwreck2.jpg',
        'miranda2.jpg',
        'shipwreck1.jpg',
        nil
      ]
      expect(subject['doi']).to eq '10.3998/mpub.9999991.blah'

      expect(subject['files_metadata'].count).to eq 12

      expect(subject['files_metadata']).to eq [
        { 'title' => ['External Resource FileSet'],
          'external_resource_url' => 'http://www.blah.com' },
        { 'title' => ['Monograph Shipwreck'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/licenses/by-sa/4.0/'],
          'exclusive_to_platform' => 'no',
          'content_type' => ['portrait'],
          'creator' => ['Smith, Benjamin'],
          'sort_date' => '2001-02-03',
          'language' => ['English'],
          'doi' => '10.3998/mpub.9999992.blah' },
        { 'title' => ['Monograph Miranda'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/publicdomain/mark/1.0/'],
          'exclusive_to_platform' => 'yes',
          'content_type' => ['audience materials'],
          'creator' => ['Waterhouse, John William'],
          'language' => ['English', 'German'],
          'doi' => '10.3998/mpub.9999993.blah' },
        { 'title' => ['External Bard Transcript 1'],
          'resource_type' => ['text'],
          'external_resource_url' => 'http://external/resource/url1',
          'exclusive_to_platform' => 'no',
          'content_type' => ['Interview Transcript'],
          'creator' => ['L\'Interviewere, Bob'],
          'sort_date' => '2010-11-12',
          'keywords' => ['interview'],
          'language' => ['English'] },
        { 'title' => ['日本語のファイル'],
          'resource_type' => ['text'],
          'license' => ['https://creativecommons.org/publicdomain/mark/1.0/'],
          'exclusive_to_platform' => 'yes',
          'content_type' => ['portrait', 'illustration'],
          'language' => ['Japanese'] },
        { 'title' => ['External Bard Transcript 2'],
          'resource_type' => ['text'],
          'external_resource_url' => 'http://external/resource/url2',
          'exclusive_to_platform' => 'no',
          'content_type' => ['Interview Transcript'],
          'creator' => ['L\'Interviewere, Bob'],
          'keywords' => ['interview'],
          'language' => ['English'] },
        { 'title' => ['Section 1 Shipwreck'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/publicdomain/mark/1.0/'],
          'exclusive_to_platform' => 'yes',
          'content_type' => ['audience materials'],
          'creator' => ['Smith'],
          'sort_date' => '2019-10-01',
          'keywords' => ['keyword1', 'keyword2'],
          'section_title' => ['Act 1: Calm Waters'],
          'language' => ['Russian'] },
        { 'title' => ['Section 1 Miranda'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/publicdomain/mark/1.0/'], # found the associated authority `term` case-insensitively
          'exclusive_to_platform' => 'yes',
          'content_type' => ['portrait'],
          'creator' => ["Waterhouse, John William\nCreator, A. Second (editor)"], # role was downcased
          'keywords' => ['regular', 'italicized'],
          'section_title' => ['Act 1: Calm Waters'],
          'language' => ['Russian', 'German', 'French'] },
        { 'title' => ['Section 2 Shipwreck'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/licenses/by-nc-nd/3.0/'], # an inactive id from licenses.yml
          'exclusive_to_platform' => 'yes',
          'content_type' => ['audience materials'],
          'creator' => ['Smith'],
          'section_title' => ['Act 2: Stirrin\' Up'],
          'language' => ['French'] },
        { 'title' => ['Section 2 Miranda'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/publicdomain/mark/1.0/'],
          'exclusive_to_platform' => 'yes',
          'content_type' => ['illustration'],
          'creator' => ['Waterhouse, John William'],
          'section_title' => ['Act 2: Stirrin\' Up'],
          'language' => ['English'] },
        { 'title' => ['Previous Shipwreck File (Again)'],
          'resource_type' => ['image'],
          'license' => ['https://creativecommons.org/licenses/by-sa/3.0/'], # an inactive id from licenses.yml
          'exclusive_to_platform' => 'yes',
          'content_type' => ['portrait', 'photograph'],
          'creator' => ['Smith'],
          'section_title' => ['Act 2: Stirrin\' Up', 'Act 3: External Stuffs'],
          'language' => ['Latin'] },
        { 'title' => ['External Bard Transcript 3'],
          'resource_type' => ['text'],
          'external_resource_url' => 'http://external/resource/url3',
          'exclusive_to_platform' => 'no',
          'content_type' => ['Interview Transcript'],
          'creator' => ['L\'Interviewere, Bob'],
          'sort_date' => '2019-01-01',
          'keywords' => ['interview'],
          'section_title' => ['Act 3: External Stuffs'],
          'language' => ['English'] }
      ]
    end
  end
end
