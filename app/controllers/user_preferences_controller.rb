class UserPreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_preference, only: [:show, :update]

  def show
    respond_to do |format|
      format.html
      format.json { render json: @user_preference }
    end
  end

  def update
    if @user_preference.update(user_preference_params)
      respond_to do |format|
        format.html { redirect_to user_preferences_path, notice: 'Preferences updated successfully.' }
        format.json { render json: @user_preference }
      end
    else
      respond_to do |format|
        format.html { render :show, alert: 'Failed to update preferences.' }
        format.json { render json: { errors: @user_preference.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update_dashboard
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    if params[:widgets].present?
      @user_preference.dashboard_widgets = params[:widgets]
    end
    
    if params[:layout].present?
      layout_params = params[:layout].permit(
        :grid_columns, :widget_spacing, :compact_mode, :auto_refresh,
        widgets: [:id, :position, :size, :collapsed, :order]
      )
      @user_preference.dashboard_layout = layout_params.to_h
    end
    
    if @user_preference.save
      render json: { status: 'success', message: 'Dashboard preferences updated' }
    else
      render json: { status: 'error', errors: @user_preference.errors }, status: :unprocessable_entity
    end
  end

  def update_theme
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    theme_params = params.require(:theme).permit(:theme, :primary_color, :secondary_color, :font_size, :compact_mode, :animation_enabled, :sidebar_collapsed)
    
    current_settings = @user_preference.theme_settings
    updated_settings = current_settings.merge(theme_params.to_h)
    @user_preference.theme_settings = updated_settings
    
    if @user_preference.save
      render json: { status: 'success', message: 'Theme preferences updated', theme: updated_settings }
    else
      render json: { status: 'error', errors: @user_preference.errors }, status: :unprocessable_entity
    end
  end

  def update_notifications
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    notification_params = params.require(:notifications).permit(
      :email_enabled, :sms_enabled, :browser_enabled, :mobile_enabled,
      :task_assigned, :task_completed, :task_overdue, :deadline_reminder,
      :festival_updates, :budget_alerts, :vendor_updates, :system_notifications,
      :digest_frequency, :quiet_hours_enabled,
      quiet_hours: [:start_time, :end_time],
      email_preferences: [:digest, :immediate, :daily, :weekly],
      mobile_preferences: [:push_enabled, :vibration, :sound]
    )
    
    current_prefs = @user_preference.notification_preferences
    updated_prefs = current_prefs.merge(notification_params.to_h)
    @user_preference.notification_preferences = updated_prefs
    
    if @user_preference.save
      render json: { status: 'success', message: 'Notification preferences updated' }
    else
      render json: { status: 'error', errors: @user_preference.errors }, status: :unprocessable_entity
    end
  end

  def toggle_quick_action
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    action_name = params[:action_name]
    enabled = params[:enabled] == 'true'
    
    if enabled
      @user_preference.enable_feature_shortcut(action_name)
    else
      @user_preference.disable_feature_shortcut(action_name)
    end
    
    render json: { 
      status: 'success', 
      message: "Quick action #{enabled ? 'enabled' : 'disabled'}", 
      quick_actions: @user_preference.quick_actions 
    }
  end

  def toggle_favorite_feature
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    feature_name = params[:feature_name]
    favorited = params[:favorited] == 'true'
    
    if favorited
      @user_preference.add_favorite_feature(feature_name)
    else
      @user_preference.remove_favorite_feature(feature_name)
    end
    
    render json: { 
      status: 'success', 
      message: "Feature #{favorited ? 'added to' : 'removed from'} favorites", 
      favorite_features: @user_preference.favorite_features 
    }
  end

  def reset_to_defaults
    @user_preference = current_user.user_preference || current_user.build_user_preference
    
    case params[:category]
    when 'dashboard'
      @user_preference.update(
        dashboard_widgets: @user_preference.send(:default_dashboard_widgets),
        dashboard_layout: @user_preference.send(:default_dashboard_layout)
      )
    when 'theme'
      @user_preference.update(theme_settings: @user_preference.send(:default_theme_settings))
    when 'notifications'
      @user_preference.update(notification_preferences: @user_preference.send(:default_notification_preferences))
    when 'shortcuts'
      @user_preference.update(
        quick_actions: @user_preference.send(:default_quick_actions),
        favorite_features: @user_preference.send(:default_favorite_features)
      )
    when 'all'
      @user_preference.destroy
      @user_preference = current_user.build_user_preference
      @user_preference.save
    end
    
    render json: { status: 'success', message: 'Preferences reset to defaults' }
  end

  def export_preferences
    @user_preference = current_user.user_preference
    
    if @user_preference
      preferences_data = {
        dashboard_widgets: @user_preference.dashboard_widgets,
        dashboard_layout: @user_preference.dashboard_layout,
        notification_preferences: @user_preference.notification_preferences,
        theme_settings: @user_preference.theme_settings,
        quick_actions: @user_preference.quick_actions,
        favorite_features: @user_preference.favorite_features,
        language: @user_preference.language,
        timezone: @user_preference.timezone,
        exported_at: Time.current.iso8601
      }
      
      send_data preferences_data.to_json, 
                filename: "festival_planner_preferences_#{current_user.id}_#{Date.current}.json",
                type: 'application/json'
    else
      redirect_to user_preferences_path, alert: 'No preferences found to export.'
    end
  end

  def import_preferences
    if params[:preferences_file].present?
      begin
        preferences_data = JSON.parse(params[:preferences_file].read)
        @user_preference = current_user.user_preference || current_user.build_user_preference
        
        # Validate and import preferences
        @user_preference.assign_attributes(
          dashboard_widgets: preferences_data['dashboard_widgets'],
          dashboard_layout: preferences_data['dashboard_layout'],
          notification_preferences: preferences_data['notification_preferences'],
          theme_settings: preferences_data['theme_settings'],
          quick_actions: preferences_data['quick_actions'],
          favorite_features: preferences_data['favorite_features'],
          language: preferences_data['language'],
          timezone: preferences_data['timezone']
        )
        
        if @user_preference.save
          redirect_to user_preferences_path, notice: 'Preferences imported successfully.'
        else
          redirect_to user_preferences_path, alert: 'Failed to import preferences: Invalid data.'
        end
      rescue JSON::ParserError
        redirect_to user_preferences_path, alert: 'Failed to import preferences: Invalid file format.'
      rescue => e
        redirect_to user_preferences_path, alert: 'Failed to import preferences: Unknown error.'
      end
    else
      redirect_to user_preferences_path, alert: 'Please select a preferences file to import.'
    end
  end

  private

  def set_user_preference
    @user_preference = current_user.user_preference || current_user.build_user_preference
  end

  def user_preference_params
    params.require(:user_preference).permit(
      :language, :timezone, :high_contrast_mode, :screen_reader_optimized, 
      :font_scale, :enable_animations, :auto_refresh_enabled, :auto_refresh_interval,
      dashboard_widgets: [], 
      quick_actions: [], 
      favorite_features: [],
      dashboard_layout: {},
      notification_preferences: {},
      theme_settings: {}
    )
  end
end