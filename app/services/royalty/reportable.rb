# frozen_string_literal: true

require 'net/ftp'

module Royalty
  module Reportable # rubocop:disable Metrics/ModuleLength
    extend ActiveSupport::Concern
    include ActionView::Helpers::NumberHelper

    def box_config
      return @box_config if @box_config.present?
      @box_config ||= begin
        filename = Rails.root.join('config', 'box.yml')
        @yaml = YAML.safe_load(File.read(filename)) if File.exist?(filename)
        @yaml ||= {}
        @yaml['lib_ptg_box']
      end
    end

    def send_reports(reports)
      dir = File.join("Library PTG Box", "HEB", "HEB Royalty Reports", "#{@start_date.strftime("%Y-%m")}_to_#{@end_date.strftime("%Y-%m")}")
      ftp = Net::FTP.open(box_config["ftp"], username: box_config["user"], password: box_config["password"], ssl: true)
      begin
        ftp.mkdir(dir)
      rescue Net::FTPPermError => e
        Rails.logger.info "[ROYALTY REPORTS] #{dir} already exists (THIS IS OK!): #{e}"
      end
      ftp.chdir(dir)
      reports.each do |name, report|
        file = Tempfile.new(name)
        file.write(CounterReporterService.csv(report))
        file.close
        ftp.putbinaryfile(file, name)
        file.unlink
        Rails.logger.info("[ROYALTY REPORTS] Put #{name}")
      end
    rescue StandardError => e
      Rails.logger.error "[ROYALTY REPORTS] FTP Error: #{e}\n#{e.backtrace.join("\n")}"
    end

    def format_hits(items)
      items.each do |item|
        item["Hits"] = number_with_delimiter(item["Hits"])
        item.map { |k, v| item[k] = number_with_delimiter(v) if k.match?(/\w{3}-\d{4}/) } # matches "Jan-2019" or whatever
      end
      items
    end

    def add_hebids(items)
      items.each_with_index do |item, index|
        monograph_noid = item["Parent_Proprietary_ID"]
        monograph_noid_idx = item.keys.index("Parent_Proprietary_ID")
        items[index] = item.to_a.insert(monograph_noid_idx + 1, ["hebid", hebids[monograph_noid]]).to_h
      end
      items
    end

    def add_copyright_holder_to_combined_report(all_items)
      all_items.each_with_index do |item, index|
        monograph_noid = item["Parent_Proprietary_ID"]
        publisher_idx = item.keys.index("Publisher")
        all_items[index] = item.to_a.insert(publisher_idx + 1, ["Copyright Holder", copyright_holders[monograph_noid]]).to_h
      end
      all_items
    end

    def reclassify_isbns(items)
      # Because of metadata cleanup, we can rely on ISBN formats being strict, like:
      # 9780520047983 (hardcover), 9780520319196 (ebook), 9780520319189 (paper)
      # So this exact matching should always work. Supposedly.
      items.each_with_index do |item, index|
        isbns = item["ISBN"].split(",")
        isbn_idx = item.keys.index("ISBN")

        hardcover = ""
        ebook = ""
        paper = ""
        isbns.each do |isbn|
          hardcover = isbn.gsub(/ \(hardcover\)/, "").strip if isbn.match?(/hardcover/)
          ebook = isbn.gsub(/ \(ebook\)/, "").strip if isbn.match?(/ebook/)
          paper = isbn.gsub(/ \(paper\)/, "").strip if isbn.match?(/paper/)
        end

        new_item =     item.to_a.insert(isbn_idx + 1, ["ebook ISBN", ebook])
        new_item = new_item.to_a.insert(isbn_idx + 2, ["hardcover ISBN", hardcover])
        new_item = new_item.to_a.insert(isbn_idx + 3, ["paper ISBN", paper]).to_h
        new_item.delete("ISBN")
        # remove these from the usage report per HELIO-3572
        new_item.delete("Parent_ISBN")
        new_item.delete("Parent_Print_ISSN")
        new_item.delete("Parent_Online_ISSN")
        items[index] = new_item
      end
      items
    end

    def hebids
      return @hebids if @hebids.present?
      @hebids = {}
      docs = ActiveFedora::SolrService.query("{!terms f=press_sim}#{@subdomain}", fl: ['id', 'identifier_tesim'], rows: 100_000)
      docs.each do |doc|
        identifier = doc['identifier_tesim']&.find { |i| i[/^heb[0-9].*/] } || ''
        @hebids[doc["id"]] = identifier
      end
      @hebids
    end

    def items_by_copyholders(items)
      return @items_by_copyholders if @items_by_copyholders.present?
      @items_by_copyholders = {}
      items.each do |item|
        this_copyholder = copyright_holders[item["Parent_Proprietary_ID"]]
        @items_by_copyholders[this_copyholder] = [] if @items_by_copyholders[this_copyholder].nil?
        @items_by_copyholders[this_copyholder] << item
      end
      @items_by_copyholders
    end

    def copyright_holders
      return @copyright_holders if @copyright_holders
      @copyright_holders = {}
      docs = ActiveFedora::SolrService.query("{!terms f=press_sim}#{@subdomain}", fl: ['id', 'copyright_holder_tesim'], rows: 100_000)
      docs.each do |doc|
        if doc["copyright_holder_tesim"].blank? || doc["copyright_holder_tesim"].first.blank?
          @copyright_holders[doc["id"]] = "no copyright holder"
        else
          @copyright_holders[doc["id"]] = doc["copyright_holder_tesim"].first
        end
      end
      @copyright_holders
    end

    def total_hits_all_rightsholders(items)
      return @total_hits_all_rightsholders if @total_hits_all_rightsholders.present?
      @total_hits_all_rightsholders = 0
      items.each do |item|
        @total_hits_all_rightsholders += item["Hits"].to_i
      end
      @total_hits_all_rightsholders
    end

    def item_report
      CounterReporter::ItemReport.new(params).report
    end
  end
end
