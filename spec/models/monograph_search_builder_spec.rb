# frozen_string_literal: true

require 'rails_helper'

describe MonographSearchBuilder do
  let(:config) { CatalogController.blacklight_config }
  let(:context) { double('context', blacklight_config: config) }
  let(:solr_params) { { fq: [] } }
  let(:search_builder) { described_class.new(context) }

  describe "#filter_by_members" do
    context "a monograph with assets" do
      let(:monograph) { build(:monograph, representative_id: cover.id) }
      let(:cover) { create(:file_set) }
      let(:file1) { create(:file_set) }
      let(:file2) { create(:file_set) }

      before do
        monograph.ordered_members << cover
        monograph.ordered_members << file1
        monograph.ordered_members << file2
        monograph.save!
        search_builder.blacklight_params['id'] = monograph.id
        search_builder.filter_by_members(solr_params)
      end
      it "creates a query for the monograph's assets but without the representative_id" do
        expect(solr_params[:fq].first).not_to match(/{!terms f=id}#{cover.id},#{file1.id},#{file2.id}/)
        expect(solr_params[:fq].first).to match(/{!terms f=id}#{file1.id},#{file2.id}/)
      end
      context 'epub' do
        let(:file2) { create(:file_set, content: File.open(File.join(fixture_path, 'moby-dick.epub'))) }
        it "creates a query for the monograph's assets but without the epub id" do
          expect(solr_params[:fq].first).not_to match(/{!terms f=id}#{file1.id},#{file2.id}/)
          expect(solr_params[:fq].first).to match(/{!terms f=id}#{file1.id}/)
        end
      end
      context 'manifest' do
        let(:file2) { create(:file_set, content: File.open(File.join(fixture_path, 'csv', 'import', 'tempest.csv'))) }
        it "creates a query for the monograph's assets but without the manifest id" do
          expect(solr_params[:fq].first).not_to match(/{!terms f=id}#{file1.id},#{file2.id}/)
          expect(solr_params[:fq].first).to match(/{!terms f=id}#{file1.id}/)
        end
      end
    end

    context "a monograph with no assets" do
      let(:empty_monograph) { create(:monograph) }
      before do
        search_builder.blacklight_params['id'] = empty_monograph.id
        search_builder.filter_by_members(solr_params)
      end
      it "creates an empty query for the monograph's assets" do
        expect(solr_params[:fq].first).to eq("{!terms f=id}")
      end
    end

    # Maybe this test doesn't belong here... but where to put it?
    # We're testing search, not really the search_builder...
    # For #386
    context "a monograph with file_sets with markdown content" do
      let(:monograph) { create(:monograph, representative_id: cover.id) }
      let(:cover) { create(:file_set, title: ["Blue"], description: ["italic _elephant_"]) }
      let(:file1) { create(:file_set, title: ["Red"], description: ["bold __spider__"]) }
      let(:file2) { create(:file_set, title: ["Yellow"], description: ["strikethrough ~~lizard~~"]) }

      before do
        monograph.ordered_members << cover
        monograph.ordered_members << file1
        monograph.ordered_members << file2
        monograph.save!
      end

      it "recieves the correct file_set after searching for italic" do
        doc = ActiveFedora::SolrService.query("{!terms f=description_tesim}elephant", rows: 10_000).first
        expect(doc[:title_tesim]).to eq(["Blue"])
      end

      it "recieves the correct result after searching for bold" do
        doc = ActiveFedora::SolrService.query("{!terms f=description_tesim}spider", rows: 10_000).first
        expect(doc[:title_tesim]).to eq(["Red"])
      end

      it "recieves the correct result after searching for strikethrough" do
        # solr doesn't need any changes in solr/config/schema.xml for strikethrough.
        # It just "does the right thing". Should test it anyway I guess.
        doc = ActiveFedora::SolrService.query("{!terms f=description_tesim}lizard", rows: 10_000).first
        expect(doc[:title_tesim]).to eq(["Yellow"])
      end
    end
  end
end
