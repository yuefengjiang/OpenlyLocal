require 'test_helper'

class CouncilsControllerTest < ActionController::TestCase

  def setup
    @member = Factory(:member)
    @council = @member.council
    @old_member = Factory(:old_member, :council => @council)
    @another_council = Factory(:another_council)
  end
  
  # index test
  context "on GET to :index" do
    
    context "with basic request" do
      setup do
        get :index
      end
  
      should_assign_to(:councils) { [@council]} # only parsed councils
      should_respond_with :success
      should_render_template :index
    end
    
    context "including unparsed councils" do
      setup do
        get :index, :include_unparsed => true
      end
  
      should_assign_to(:councils) { Council.find(:all, :order => "name")} # all councils
      should_respond_with :success
      should_render_template :index
      should "class unparsed councils as unparsed" do
        assert_select "#councils .unparsed", @another_council.name
      end
      should "class parsed councils as parsed" do
        assert_select "#councils .parsed", @council.name
      end
    end
    
    context "with xml requested" do
      setup do
        get :index, :format => "xml"
      end
  
      should_assign_to(:councils) { [@council]}
      should_respond_with :success
      should_render_without_layout
      should_respond_with_content_type 'application/xml'
    end
    
    context "with json requested" do
      setup do
        get :index, :format => "json"
      end
  
      should_assign_to(:councils) { [@council]}
      should_respond_with :success
      should_render_without_layout
      should_respond_with_content_type 'application/json'
    end
  end

  # show test
  context "on GET to :show for first record" do
    
    context "with basic request" do
      setup do
        get :show, :id => @council.id
      end

      should_assign_to(:council) { @council}
      should_respond_with :success
      should_render_template :show
      should_assign_to(:members) { @council.members.current }

      should "list all members" do
       assert_select "#members li", @council.members.current.size
      end
    end
    
    context "with xml requested" do
      setup do
        get :show, :id => @council.id, :format => "xml"
      end

      should_assign_to(:council) { @council}
      should_respond_with :success
      should_render_without_layout
      should_respond_with_content_type 'application/xml'
    end
    
    context "with json requested" do
      setup do
       get :show, :id => @council.id, :format => "json"
      end

      should_assign_to(:council) { @council}
      should_respond_with :success
      should_render_without_layout
      should_respond_with_content_type 'application/json'
    end
  end  

  # new test
  context "on GET to :new without auth" do
    setup do
      get :new
    end

    should_respond_with 401
  end
  
  context "on GET to :new" do
    setup do
      stub_authentication
      get :new
    end

    should_assign_to(:council)
    should_respond_with :success
    should_render_template :new

    should "show form" do
      assert_select "form#new_council"
    end
    
    should "show possible portal_systems in form" do
      assert_select "select#council_portal_system_id"
    end
  end  

  # create test
   context "on POST to :create" do
     setup do
       @council_params = { :name => "Some Council", 
                           :url => "http://somecouncil.gov.uk"}
     end
     
     context "description" do
       setup do
         post :create, :council => @council_params
       end

       should_respond_with 401
     end
     
     context "with valid params" do
       setup do
         stub_authentication
         post :create, :council => @council_params
       end
     
       should_change "Council.count", :by => 1
       should_assign_to :council
       should_redirect_to( "the show page for council") { council_path(assigns(:council)) }
       should_set_the_flash_to "Successfully created council"
     
     end
     
     context "with invalid params" do
       setup do
         stub_authentication
         post :create, :council => @council_params.except(:name)
       end
     
       should_not_change "Council.count"
       should_assign_to :council
       should_render_template :new
       should_not_set_the_flash
     end
   end  

   # edit test
   context "on GET to :edit without auth" do
     setup do
       get :edit, :id => @council
     end

     should_respond_with 401
   end

   context "on GET to :edit with existing record" do
     setup do
       stub_authentication
       get :edit, :id => @council
     end

     should_assign_to(:council)
     should_respond_with :success
     should_render_template :edit

     should "show form" do
       assert_select "form#edit_council_#{@council.id}"
     end
   end  

  # update test
  context "on PUT to :update" do
    setup do
      @council_params = { :name => "New Name for SomeCouncil", 
                          :url => "http://somecouncil.gov.uk/new"}
    end
    
    context "without auth" do
      setup do
        put :update, :id => @council.id, :council => @council_params
      end

      should_respond_with 401
    end
    
    context "with valid params" do
      setup do
        stub_authentication
        put :update, :id => @council.id, :council => @council_params
      end
    
      should_not_change "Council.count"
      should_change "@council.reload.name", :to => "New Name for SomeCouncil"
      should_change "@council.reload.url", :to => "http://somecouncil.gov.uk/new"
      should_assign_to :council
      should_redirect_to( "the show page for council") { council_path(assigns(:council)) }
      should_set_the_flash_to "Successfully updated council"
    
    end
    
    context "with invalid params" do
      setup do
        stub_authentication
        put :update, :id => @council.id, :council => {:name => ""}
      end
    
      should_not_change "Council.count"
      should_not_change "@council.reload.name"
      should_assign_to :council
      should_render_template :edit
      should_not_set_the_flash
    end

  end  

end
