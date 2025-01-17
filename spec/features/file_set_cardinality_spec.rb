# frozen_string_literal: true

require 'rails_helper'

describe 'FileSet Cardinality' do
  # See #645
  # We want to assert that the file_set fields that we have in fedora, solr and forms
  # have the same cardinality: the field is multi-valued across everything or not.
  # Right now it seems to be a bit of a mixture. Maybe that's ok as long as we have
  # this test to assert what's true?
  let(:press) { create(:press, subdomain: 'umich') }
  let(:user) { create(:platform_admin) }
  let(:monograph) { create(:monograph, user: user, press: press.subdomain) }
  let(:cover) {
    create(:file_set, allow_display_after_expiration: "lo-res",
                      allow_download: "yes",
                      allow_download_after_expiration: "no",
                      allow_hi_res: "yes",
                      alt_text: ["This is the alt text"],
                      caption: ["This is the caption"],
                      closed_captions: ["This is a closed caption"],
                      content_type: ["drawing", "illustration"],
                      contributor: ["Thomas, John (playwright, author)\nGuy, Other (lackey)"],
                      copyright_holder: "This is the © Copyright Holder",
                      copyright_status: "in-copyright",
                      creator: ["Smith, John (author, artist, photographer)\nCoauthor, Sally"],
                      credit_line: "Copyright by Some Person...",
                      date_created: ["2017-01-01"],
                      display_date: ["circa. 2000"],
                      doi: "",
                      hdl: "",
                      exclusive_to_platform: "yes",
                      external_resource_url: "https://example.com/blah",
                      holding_contact: "Some museum or something somewhere",
                      keywords: ["dogs", "cats", "fish"],
                      permissions_expiration_date: "2020-01-01",
                      rights_granted: "Non-exclusive, North America, term-limited",
                      license: ['http://creativecommons.org/publicdomain/mark/1.0/'],
                      section_title: ["Chapter 2"],
                      sort_date: "1997-01-11",
                      transcript: "This is the transcript",
                      translation: ["This is a translation"],
                      visual_descriptions: ["This is a visual description"])
  }
  let!(:sipity_entity) do
    create(:sipity_entity, proxy_for_global_id: monograph.to_global_id.to_s)
  end

  before do
    monograph.ordered_members << cover
    monograph.save!
    cover.save!
    login_as user
    stub_out_redis
  end

  context "with solr_doc" do
    let(:doc) { SolrDocument.new(cover.to_solr) }

    it "On the file_set edit page" do
      visit edit_hyrax_file_set_path(cover.id)

      # These are assertions of what is, not neccessarily what is "right"
      expect(cover.allow_display_after_expiration).to eql 'lo-res'
      expect(doc.allow_display_after_expiration).to eql 'lo-res'
      expect(find('#file_set_allow_display_after_expiration')[:class]).not_to include 'multi-text-field'

      expect(cover.allow_download).to eql 'yes'
      expect(doc.allow_download).to eql 'yes'
      expect(find('#file_set_allow_download')[:class]).not_to include 'multi-text-field'

      expect(cover.allow_download_after_expiration).to eql 'no'
      expect(doc.allow_download_after_expiration).to eql 'no'
      expect(find('#file_set_allow_download_after_expiration')[:class]).not_to include 'multi-text-field'

      expect(cover.allow_hi_res).to eql 'yes'
      expect(doc.allow_hi_res).to eql 'yes'
      expect(find('#file_set_allow_hi_res')[:class]).not_to include 'multi-text-field'

      expect(cover.alt_text).to match_array(['This is the alt text'])
      expect(doc.alt_text).to match_array(['This is the alt text'])
      expect(find('#file_set_alt_text')[:class]).not_to include 'multi-text-field'

      expect(cover.caption).to match_array(['This is the caption'])
      expect(doc.caption).to match_array(['This is the caption'])
      expect(find('#file_set_caption')[:class]).not_to include 'multi-text-field'

      expect(cover.closed_captions).to match_array(['This is a closed caption'])
      expect(doc.closed_captions).to eql 'This is a closed caption'
      expect(find('#file_set_closed_captions')[:class]).not_to include 'multi-text-field'

      expect(cover.content_type).to match_array(['drawing', 'illustration'])
      expect(doc.content_type).to match_array(['drawing', 'illustration'])
      expect(find('#file_set_content_type')[:class]).to include 'multi-text-field'

      # contributor is a Hyrax::BasicMetadata multi-valued field we're using as a single-value (in Fedora) field...
      # with entries separated by a new line.
      expect(cover.contributor).to match_array(["Thomas, John (playwright, author)\nGuy, Other (lackey)"])
      expect(doc.contributor).to match_array(['Thomas, John (playwright, author)', 'Guy, Other (lackey)'])
      expect(find('#file_set_contributor')[:class]).not_to include 'multi-text-field'

      expect(cover.copyright_holder).to eql 'This is the © Copyright Holder'
      expect(doc.copyright_holder).to eql 'This is the © Copyright Holder'
      expect(find('#file_set_copyright_holder')[:class]).not_to include 'multi-text-field'

      expect(cover.copyright_status).to eql 'in-copyright'
      expect(doc.copyright_status).to eql 'in-copyright'
      expect(find('#file_set_copyright_status')[:class]).not_to include 'multi-text-field'

      # creator is a Hyrax::BasicMetadata multi-valued field we're using as a single-value (in Fedora) field...
      # with entries separated by a new line. Roles are indexed separately in `primary_creator_role`
      expect(cover.creator).to match_array(["Smith, John (author, artist, photographer)\nCoauthor, Sally"])
      expect(doc.creator).to match_array(['Smith, John', 'Coauthor, Sally'])
      expect(find('#file_set_caption')[:class]).not_to include 'multi-text-field'
      expect(doc.primary_creator_role).to match_array(["author", "artist", "photographer"])

      expect(cover.credit_line).to eql 'Copyright by Some Person...'
      expect(doc.credit_line).to eql 'Copyright by Some Person...'
      expect(find('#file_set_credit_line')[:class]).not_to include 'multi-text-field'

      expect(cover.date_created).to match_array(["2017-01-01"])
      expect(doc.date_created).to match_array(["2017-01-01"])

      expect(cover.display_date).to match_array(['circa. 2000'])
      expect(doc.display_date).to match_array(['circa. 2000'])
      expect(find('#file_set_display_date')[:class]).to include 'multi-text-field'

      expect(cover.doi).to eql ''
      expect(doc.doi).to eql ''
      expect(find('#file_set_doi')[:class]).not_to include 'multi-text-field'

      expect(cover.hdl).to eql ''
      expect(doc.hdl).to eql ''
      expect(find('#file_set_hdl')[:class]).not_to include 'multi-text-field'

      expect(cover.exclusive_to_platform).to eql 'yes'
      expect(doc.exclusive_to_platform).to eql 'yes'
      expect(find('#file_set_exclusive_to_platform')[:class]).not_to include 'multi-text-field'

      expect(cover.external_resource_url).to eql 'https://example.com/blah'
      expect(doc.external_resource_url).to eql 'https://example.com/blah'
      expect(find('#file_set_external_resource_url')[:class]).not_to include 'multi-text-field'

      expect(cover.holding_contact).to eql 'Some museum or something somewhere'
      expect(doc.holding_contact).to eql 'Some museum or something somewhere'
      expect(find('#file_set_holding_contact')[:class]).not_to include 'multi-text-field'

      expect(cover.keywords).to match_array(["dogs", "cats", "fish"])
      expect(doc.keywords).to match_array(["dogs", "cats", "fish"])
      expect(find('#file_set_keywords')[:class]).to include 'multi-text-field'

      expect(cover.permissions_expiration_date).to eql '2020-01-01'
      expect(doc.permissions_expiration_date).to eql '2020-01-01'
      expect(find('#file_set_permissions_expiration_date')[:class]).not_to include 'multi-text-field'

      expect(cover.rights_granted).to eql 'Non-exclusive, North America, term-limited'
      expect(doc.rights_granted).to eql 'Non-exclusive, North America, term-limited'
      expect(find('#file_set_rights_granted')[:class]).not_to include 'multi-text-field'

      expect(cover.license).to match_array(['http://creativecommons.org/publicdomain/mark/1.0/'])
      expect(doc.license).to eql ['http://creativecommons.org/publicdomain/mark/1.0/']
      expect(find('#file_set_license')[:class]).not_to include 'multi-text-field'

      expect(cover.section_title).to match_array(["Chapter 2"])
      expect(doc.section_title).to match_array(["Chapter 2"])
      expect(find('#file_set_section_title')[:class]).to include 'multi-text-field'

      expect(cover.sort_date).to eql '1997-01-11'
      expect(doc.sort_date).to eql '1997-01-11'
      expect(find('#file_set_sort_date')[:class]).not_to include 'multi-text-field'

      expect(cover.transcript).to eql 'This is the transcript'
      expect(doc.transcript).to eql 'This is the transcript'
      expect(find('#file_set_transcript')[:class]).not_to include 'multi-text-field'

      expect(cover.translation).to match_array(["This is a translation"])
      expect(doc.translation).to eql 'This is a translation'
      expect(find('#file_set_translation')[:class]).not_to include 'multi-text-field'

      expect(cover.visual_descriptions).to match_array(['This is a visual description'])
      expect(doc.visual_descriptions).to eql 'This is a visual description'
      expect(find('#file_set_visual_descriptions')[:class]).not_to include 'multi-text-field'
    end
  end
end
