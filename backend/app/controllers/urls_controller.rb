class UrlsController < ApplicationController
  def index
    @url = Url.new
  end

  def new
    @url = Url.new
  end

  def create
    @url = Url.new(url_params)
    if @url.save
      redirect_to url_path(@url), notice: 'URL was successfully shortened'
    else
      render :new
    end
  end

  def show
    @url = Url.find(params[:id])
    #@url.increment!(:visit_count)
    render :show
  end
  def show_with_token
    short = params[:short]
    @url = Url.find_by(short_url: params[:short])
    
    if @url.nil?
      redirect_to root_url, alert: "URL not found."
    else
      @url.increment!(:visit_count)
      @url.visits.create(ip_address: request.remote_ip)
      redirect_to @url.original_url, allow_other_host: true
    end
  end

  def stats
    @url = Url.find_by!(short_url: params[:token])
    @visits = @url.visits
  end

  private
  def url_params
    params.require(:url).permit(:original_url, :alias)
  end
end
