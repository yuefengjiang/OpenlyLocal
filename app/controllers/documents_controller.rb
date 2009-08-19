class DocumentsController < ApplicationController
  before_filter :show_rss_link, :only => :index
  
  def index
    @council = Council.find(params[:council_id])
    @documents = params[:term] ? @council.meeting_documents.find(:all, :select => "documents.*", :conditions => ["body LIKE ?", "%#{params[:term]}%"] ) : @council.meeting_documents.all(:select => "documents.*")
    @title = params[:term] ? "Committee documents with '#{params[:term]}'" : "Committee documents"
    respond_to do |format|
      format.html
      format.xml { render :xml => @documents.to_xml }
      format.json { render :json => @documents.to_json }
      format.rss { render :layout => false }
    end
  end
  
  def show
    @document = Document.find(params[:id])
    @council = @document.document_owner.council
    @title = @document.extended_title
  end

end
