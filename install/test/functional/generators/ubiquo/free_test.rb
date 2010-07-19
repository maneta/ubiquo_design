require File.dirname(__FILE__) + '/../../../test_helper'

class FreeGeneratorUbiquoTest < ActionController::TestCase
  tests Ubiquo::ComponentsController

  def test_edit_new_form
    login_as
    component, page = insert_component({}, {}, false)
    get :show, :page_id => page.id, 
               :id => component.id
    assert_response :success
  end
  
  def test_edit_form
    login_as
    component, page = insert_component(component_attributes)
    get :show, :page_id => page.id, 
               :id => component.id
    assert_response :success
  end

  def test_form_submit
    login_as
    component, page = insert_component(component_attributes)
    xhr :post, :update, :page_id => page.id, 
                        :id => component.id, 
                        :component => component_attributes
    assert_response :success
  end

  def test_form_submit_with_errors
    login_as
    component, page = insert_component({}, {}, false)
    xhr :post, :update, :page_id => page.id, 
                        :id => component.id, 
                        :component => {}
    assert_response :success
    assert_select_rjs "error_messages"
  end

  private

  def component_attributes
    {
      :content => 'Example content',
    }
  end
  
  def insert_component(component_options = {}, component_type_options = {}, validation = true)
    component_type_options.reverse_merge!({
      :key => "free", 
      :subclass_type => "Free"
    })
    insert_component_in_page(component_type_options, component_options, [], validation)      
  end
         
end