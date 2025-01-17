# frozen_string_literal: true

Hyrax::DownloadsController.class_eval do # rubocop:disable Metrics/BlockLength
  prepend(DownloadsControllerBehavior = Module.new do
    # for animated GIF files we use the repo asset for display. They need to be "downloadable" no matter what.
    delegate :animated_gif?, to: :presenter

    def show # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      if closed_captions?
        render plain: presenter.closed_captions
      elsif visual_descriptions?
        render plain: presenter.visual_descriptions
      elsif file.present? && (thumbnail? || jpeg? || video? || sound? || animated_gif? || allow_download?)
        # See #401
        if file.is_a? String
          # For derivatives stored on the local file system
          response.headers['Accept-Ranges'] = 'bytes'
          response.headers['Content-Length'] = File.size(file).to_s
          file.sub!(/releases\/\d+/, "current")
          response.headers['X-Sendfile'] = file
          send_file file, derivative_download_options
        else
          CounterService.from(self, presenter).count(request: 1)
          self.status = 200
          send_file_headers! content_options.merge(disposition: disposition(presenter))
          response.headers['Content-Length'] ||= file.size.to_s
          response.headers['Last-Modified'] = asset.modified_date.utc.strftime("%a, %d %b %Y %T GMT")
          stream_body file.stream
        end
      else
        render 'hyrax/base/unauthorized', status: :unauthorized
      end
    end

    def disposition(presenter)
      return "inline" if presenter.pdf_ebook? == false && presenter.file_format&.match?(/^pdf/i)
      "attachment"
    end

    # going to tweak this function from Hyrax to return the thumbnail if the full-size screenshot is empty
    def load_file
      file_reference = params[:file]

      return default_file unless file_reference
      return extracted_text_file if file_reference == 'extracted_text'

      file_path = Hyrax::DerivativePath.derivative_path_for_reference(params[asset_param_key], file_reference)
      # pre-tweak this is the last line
      # File.exist?(file_path) ? file_path : nil

      if File.exist?(file_path)
        file_path
      elsif jpeg?
        # you wanted the full-size poster, but it doesn't exist... you get the thumbnail
        file_path = Hyrax::DerivativePath.derivative_path_for_reference(params[asset_param_key], 'thumbnail')
        File.exist?(file_path) ? file_path : nil
      end
    end

    def extracted_text_file
      # just copying default_file behavior with :extracted_text instead of default_content_path (a.k.a. :original_file)
      association = dereference_file(:extracted_text)
      association&.reader
    end

    def presenter
      Hyrax::PresenterFactory.build_for(ids: [params[:id]], presenter_class: Hyrax::FileSetPresenter, presenter_args: current_ability).first
    end

    def mime_type_for(file)
      # See #427
      mime_type = `file --brief --mime-type #{file.shellescape}` || MIME::Types.type_for(File.extname(file)).first.content_type
      mime_type.chomp
    end

    def allow_download?
      ResourceDownloadOperation.new(current_actor, Sighrax.from_noid(params[:id])).allowed?
    end

    def thumbnail?
      params[:file] == 'thumbnail'
    end

    def jpeg?
      # want this for HTML5 video tag poster attribute, it's a full-size screenshot of the video
      params[:file] == 'jpeg'
    end

    def video?
      # video "previews"
      params[:file] == 'webm' || params[:file] == 'mp4'
    end

    def sound?
      # sound "previews"
      params[:file] == 'mp3' || params[:file] == 'ogg'
    end

    def closed_captions?
      params[:file] == 'captions_vtt'
    end

    def visual_descriptions?
      params[:file] == 'descriptions_vtt'
    end
  end)
end
