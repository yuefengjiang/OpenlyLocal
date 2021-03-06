class WardsController < ApplicationController
  before_filter :authenticate, :except => [:show, :index]
  before_filter :find_ward, :except => [:index]
  before_filter :linked_data_available, :only => :show
  before_filter :enable_google_maps, :only => :show

  caches_action :show, :cache_path => Proc.new {|c| [c.instance_variable_get(:@ward).cache_key,c.params[:format]].join('.') }, 
                       :if => Proc.new {|c| c.instance_variable_get(:@ward) }, 
                       :expires_in  => 12.hours

  def index
    @council = Council.find(params[:council_id]) if params[:council_id]
    @output_area_classification = OutputAreaClassification.find(params[:output_area_classification_id]) if params[:output_area_classification_id]
    @wards = @council ? @council.wards.current : Ward.restrict_to_oac(params).current.paginate(:page => valid_page, :include => :council)
    @title = @output_area_classification ? "#{@output_area_classification.title} Wards" : "Current Wards"
    @title += " :: Page #{valid_page}" unless @council
    options = {:include => [:council, :output_area_classification]}
    respond_to do |format|
      format.html
      format.xml do
        if @council 
         render :xml => @wards.to_xml
        else
         render :xml => @wards.to_xml(options) { |xml|
                    xml.tag! 'total-entries', @wards.total_entries
                    xml.tag! 'per-page', @wards.per_page
                    xml.tag! 'page', valid_page
                  }
        end
        
      end
      format.json do
        if @council 
          render :json => @wards.to_json
        else
          render :json => { :page => valid_page,
                            :per_page => @wards.per_page,
                            :total_entries => @wards.total_entries,
                            :wards => @wards.to_json(options)
                          }
                
        end
        
      end
      # format.xml { render :xml => @wards.to_xml(:include => [:members, :committees, :meetings]) }
    end
  end
  
  def show
    @council = @ward.council
    @comparison_ward = Ward.find(params[:compare_with]) if params[:compare_with]
    @members = @ward.members.current
    @committees = @ward.committees
    @title = @comparison_ward ? "Ward comparison: #{@ward.name} & #{@comparison_ward.name}": "#{@ward.name} ward"
    respond_to do |format|
      format.html { render :template => @comparison_ward ? 'wards/comparison' : 'wards/show' }
      format.xml { render :xml => @ward.to_xml(:include => [:members, :committees, :meetings, :output_area_classification]) }
      format.rdf 
      format.json { render :json => @ward.to_json(:include => [:members, :committees, :meetings, :output_area_classification]) }
    end
  end
  
  def edit
  end
  
  def update
    if @ward.update_attributes(params[:ward])
      flash[:notice] = "Successfully updated ward"
      redirect_to ward_url(@ward)
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    @council = @ward.council
    @ward.destroy
    flash[:notice] = "Successfully destroyed ward"
    redirect_to council_url(@council)
  end
  
  private
  def find_ward
    @ward = 
    case 
    when params[:snac_id]
      Ward.find_by_snac_id(params[:snac_id])
    when params[:os_id]
      Ward.find_by_os_id(params[:os_id])
    else
      Ward.find(params[:id])
    end
  end
end
