class CouncilsController < ApplicationController
  before_filter :authenticate, :except => [:index, :show]
  before_filter :linked_data_available, :only => :show
  before_filter :find_council, :except => [:index, :new, :create]
  caches_action :index, :show
  
  def index
    @councils = Council.find_by_params(params.except(:controller, :action, :format))
    @title = params[:include_unparsed] ? "All UK Local Authorities/Councils" : "UK Local Authorities/Councils With Opened Up Data"
    @title += " With Term '#{params[:term]}'" if params[:term]
    @title += " With SNAC id '#{params[:snac_id]}'" if params[:snac_id]
    respond_to do |format|
      format.html
      format.xml { render :xml => @councils.to_xml(:include => nil) }
      format.json { render :json =>  @councils.to_json }
      format.rdf
    end
  end
  
  def show
    @members = @council.members.current
    @committees = @council.active_committees
    @meetings = @council.meetings.forthcoming.all(:limit => 11)
    @documents = @council.meeting_documents.all(:limit => 11)
    @wards = @council.wards
    @party_breakdown = @council.party_breakdown
    @page_description = "Information and statistics about #{@council.title}"
    respond_to do |format|
      format.html
      format.xml { render :xml => @council.to_detailed_xml }
      format.json { render :as_json => @council.to_detailed_xml }
      format.rdf
    end
  end
  
  def new
    @council = Council.new
  end
  
  def create
    @council = Council.new(params[:council])
    @council.save!
    flash[:notice] = "Successfully created council"
    redirect_to council_path(@council)
  rescue
    render :action => "new"
  end
  
  def edit
  end
  
  def update
    @council.update_attributes!(params[:council])
    flash[:notice] = "Successfully updated council"
    redirect_to council_path(@council)
  rescue
    render :action => "edit"
  end
  
  private
  def find_council
    @council = params[:id] ? Council.find(params[:id]) : Council.find_by_snac_id(params[:snac_id])
  end
  
end
