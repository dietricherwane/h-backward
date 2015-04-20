module ApplicationHelper
  def flash_class(level)
    case level
    when :notice then "alert alert-info"
    when :success then "alert alert-success"
    when :error then "alert alert-error"
    when :alert then "alert alert-error"
    end
  end
  
  def fields_in_error_formating(field_name)
	  @information.errors[:"#{field_name}"].blank? ? 'row-form' : 'row-form error'
	end
end
