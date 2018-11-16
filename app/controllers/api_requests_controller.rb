# frozen_string_literal: true

class APIRequestsController < ApplicationController
  before_action :set_api_request, only: %i[show destroy]

  def index
    @api_requests = APIRequest.order(created_at: :desc).page(params[:page])
  end

  def truncate
    @api_requests = APIRequest.all
    @api_requests.delete_all
    respond_to do |format|
      format.html { redirect_to api_requests_url, notice: 'API Requests was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def show; end

  def destroy
    @api_request.destroy
    respond_to do |format|
      format.html { redirect_to api_requests_url, notice: 'API Request was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_api_request
      @api_request = APIRequest.find(params[:id])
    end
end
