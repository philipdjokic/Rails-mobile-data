class IosFbAdDeviceService

  DEVICE_USERNAME = 'root'
  DEVICE_PASSWORD = 'padmemyboo'
  MAX_SCROLL_ITEMS = 50
  IMAGE_FOLDER_PATH = File.join('/var', 'mobile', 'Media', 'DCIM', '100APPLE')
  SCRIPTS_PATH = File.join(Rails.root, 'server', 'ios_fb_scripts')
  SCRIPTS_PREFIX = SCRIPTS_PATH.split('/').last

  # Error types
  class CriticalDeviceError < StandardError
    attr_reader :ios_device_id
    def initialize(msg, ios_device_id)
      @ios_device_id = ios_device_id
      super(msg)
    end
  end

  def initialize(ios_fb_ad_job_id, device, fb_account, bid: nil)
    @device = device
    @fb_account = fb_account
    @ios_fb_ad_job_id = ios_fb_ad_job_id
    @has_switched = false
    @bid = bid
    @results = []
  end

  def cycle_account
    Net::SSH.start(@device.ip, DEVICE_USERNAME, :password => DEVICE_PASSWORD) do |ssh|
      setup(ssh)
      log_debug "Setup done"
      open_fb(ssh)
      log_debug "Opened fb"
      log_in(ssh)
      log_debug "Logged in"
      sleep 5
      log_out(ssh)
      log_debug "Logged out"
    end
  end

  def scrape
    begin
      Net::SSH.start(@device.ip, DEVICE_USERNAME, :password => DEVICE_PASSWORD) do |ssh|
        begin
          setup(ssh)

          # return delete_screenshots(ssh)
          open_fb(ssh)

          log_in(ssh) if Rails.env.production?

          log_debug "Sleeping to let DOM load"
          sleep 5

          scroll(ssh)

          store_results

          log_out(ssh) if Rails.env.production?

          teardown(ssh)

          @results
        rescue => e
          log_debug "Rescuing Exception"
          store_exception(e)
          store_results
          raise e if e.class == CriticalDeviceError

          log_out(ssh) if is_logged_in?(ssh) && Rails.env.production?
          teardown(ssh)
          @results
        end
      end
    rescue => e
      log_debug "Rescuing top-level exception"
      store_exception(e)
      store_results
      raise e if e.class == CriticalDeviceError
      @results
    end
  end

  def store_results
    log_debug "Storing Results"
    @results.each do |entry|
      next if entry.nil? || entry[:stored_success]
      begin
        ios_fb_ad = save_entry(entry)
        entry[:stored_success] = true
        trigger_processing(ios_fb_ad)
      rescue => e
        store_exception(e)
      end
    end
  end

  def save_entry(entry)
    row = {}

    # Store the image columns
    row[:ad_image] = File.open(entry[:ad_image_path]) if Rails.env.production?
    row[:ad_info_image] = File.open(entry[:ad_info_image_path]) if Rails.env.production?

    entry_columns = [
      :link_contents,
      :ad_info_html,
      :feed_index,
      :carousel
    ]

    entry_columns.each do |col|
      row[col] = entry[col]
    end

    # metadata
    row[:ios_fb_ad_job_id] = @ios_fb_ad_job_id
    row[:fb_account_id] = @fb_account.id
    row[:ios_device_id] = @device.id

    row[:status] = :preprocessed

    IosFbAd.create!(row)
  end

  def trigger_processing(ios_fb_ad)
    return unless Rails.env.production?

    if @bid
      begin
        batch = Sidekiq::Batch.new(@bid)
        batch.jobs do
          IosFbProcessingWorker.perform_async(ios_fb_ad.id)
        end
      rescue Sidekiq::Batch::NoSuchBatch => e
        store_exception(e)
        IosFbProcessingWorker.perform_async(ios_fb_ad.id)
      end
    else
      IosFbProcessingWorker.perform_async(ios_fb_ad.id)
    end

  end

  def store_exception(error)
    IosFbAdException.create!({
      ios_fb_ad_job_id: @ios_fb_ad_job_id,
      fb_account_id: @fb_account.id,
      ios_device_id: @device.id,
      error: error.message,
      backtrace: error.backtrace
    })
  end

  def run_command(ssh, command, description, expected_output = nil)
    begin
      # add additional check to ensure cycript command doesn't hang indefinitely
      is_cycript = /cycript -p (\w+)/.match(command)
      if (is_cycript && !(ssh.exec! "ps aux | grep #{is_cycript[1]} | grep -v grep"))
        raise "Running cycript on app #{is_cycript[1]} but app is not running or crashed"
      end
      resp = ssh.exec! command
      if expected_output != nil && resp.chomp != expected_output
        raise "Expected output #{expected_output}. Received #{resp.chomp}"
      end

      is_stouch = /stouch (touch|swipe)/.match(command)

      if is_stouch && resp && resp.match(/ST Error:/)
        raise CriticalDeviceError.new(resp, @device.id)
      end

      return resp
    rescue CriticalDeviceError => e
      raise e
    rescue => error
      raise "Error during #{description} with command: #{command}. Message: #{error.message}"
    end
  end

  def log_debug(str)
    prefix = "acct#{@fb_account.id},dev#{@device.id}: "
    puts prefix + str
  end

  def setup(ssh)
    # install cycript scripts
    log_debug "Installing fb scripts"
    `/usr/local/bin/sshpass -p #{DEVICE_PASSWORD} scp -r #{SCRIPTS_PATH} #{DEVICE_USERNAME}@#{@device.ip}:~`
    log_debug "Done installing"
  end

  def open_fb(ssh)
    log_debug "Opening FB"
    run_command(ssh, 'open com.facebook.Facebook', 'Open the facebook app')
    sleep 1.5
    run_file(ssh, 'Facebook', 'fb_utilities.cy')
    sleep 1.5
  end

  def get_feed_info(ssh)
    info = JSON.parse(run_command(ssh, "cycript -p Facebook #{File.join(SCRIPTS_PREFIX, 'find_items.cy')}", 'Get information about the available feed').chomp)

    section = info['section']
    items_count = info['itemsCount']

    log_debug "Found #{items_count} items in section #{section}"

    {
      section: section,
      items_count: items_count
    }
  end

  def refresh_item(ssh, index)
    2.times do |n|
      refresh_filename = "#{index}_refresh.cy"
      resp = run_file(ssh, 'Facebook', refresh_filename)
      sleep 0.5
    end
  end

  def scroll_to_item(ssh, index, top: true)
    scroll_filename = top ? "#{index}_scroll.cy" : "#{index}_bottom_scroll.cy"
    run_command(ssh, "cycript -p Facebook #{File.join(SCRIPTS_PREFIX, scroll_filename)}", "Scroll to item #{index}")
  end

  def check_item(ssh, index)
    check_filename = "#{index}_check.cy"
    resp = run_command(ssh, "cycript -p Facebook #{File.join(SCRIPTS_PREFIX, check_filename)}", "Check item #{index}")
  end

  def scroll(ssh)
    item_index = 0
    # start with dummy information so that scripts are generated automatically
    info = {
      items_count: 0,
      section: -1
    }

    while item_index < MAX_SCROLL_ITEMS
      if item_index >= info[:items_count]
        # need to get more items
        refresh_feed_items(ssh, info[:items_count])
        info = create_section_scripts(ssh)
      end

      scroll_to_item(ssh, item_index)
      log_debug "Scrolled to item #{item_index}"

      refresh_item(ssh, item_index) if @has_switched

      resp = check_item(ssh, item_index)
      log_debug "Checked item #{item_index}. Response: #{resp}"

      if command_success?(resp)
        # because of weird cell states, validate
        refresh_item(ssh, item_index)
        resp = check_item(ssh, item_index)
        log_debug "Checked item #{item_index}. Response: #{resp}"
      end

      analyze_item(ssh, item_index, info[:section]) if command_success?(resp)
      item_index += 1
    end

    log_debug "Finished scrolling through #{item_index} items"
  end

  # function assumes you're at the bottom of the available items in the feed
  def refresh_feed_items(ssh, prior_count)

    scroll = {
      start: {
        x: 50,
        y: 500
      },
      finish: {
        x: 50,
        y: 200
      }
    }

    scroll_screen(ssh, start: scroll[:start], finish: scroll[:finish])
    sleep 2 # let apple load the feed
    scroll_screen(ssh, start: scroll[:start], finish: scroll[:finish])
    sleep 2

    after = get_feed_info(ssh)

    raise "Could not generate more items in the feed" unless prior_count < after[:items_count]

    after
  end

  def create_section_scripts(ssh)

    info = get_feed_info(ssh)

    run_command(ssh, "cd #{SCRIPTS_PREFIX} && ./scroll_generator.sh #{info[:section]} #{info[:items_count]}" , 'Create scripts for each available section in the news feed')

    log_debug "Created scripts"
    info
  end

  def press_screen(ssh, x:, y:, orientation: 1)
    run_command(ssh, "stouch touch #{x} #{y} #{orientation}", "Touch screen in orientation #{orientation} at location #{x}, #{y}")
  end

  def scroll_screen(ssh, start:, finish:, duration: 0.5)
    run_command(ssh, "stouch swipe #{start[:x]} #{start[:y]} #{finish[:x]} #{finish[:y]} #{duration}", "Scroll screen from #{start[:x]},#{start[:y]} to #{finish[:x]},#{finish[:y]}")
  end


  def analyze_item(ssh, index, section)
    run_command(ssh, "cd #{SCRIPTS_PREFIX} && ./template_button_scripts.sh #{section} #{index}", 'Template the button clicking scripts')

    log_debug "checking if carousel"
    resp = run_file(ssh, 'Facebook', "determine_ad_carousel_#{section}_#{index}.cy")

    if command_success?(resp)
      log_debug "Running carousel logic"
      count = resp.split(':').last.strip.to_i
      if count <= 0
        if @has_switched # sometimes there is a screwy state if app switching
          log_debug "Succeeded but found a section with 0 items. Moving on"
          return  
        else
          raise "Unexpected number of ads #{count} from response #{resp}" 
        end
      end

      run_command(ssh, "cd #{SCRIPTS_PREFIX} && ./generate_ad_swipes.sh #{section} #{index} #{count}", 'Template the ad swiping scripts')

      count.times do |n|
        log_debug "Trying Ad #{n} in carousel"
        run_and_validate_success(ssh, 'Facebook', "#{n}_ad_swipe.cy")
        sleep 1
        refresh_item(ssh, index)
        results_info = analyze_ad(ssh, index, section)
        next unless results_info
        results_info[:carousel] = true
        @results.push(results_info)
      end
    else
      log_debug "Running single ad logic"
      results_info = analyze_ad(ssh, index, section)
      results_info[:carousel] = false
      @results.push(results_info)
    end

  end

  def analyze_ad(ssh, index, section)
    success = click_ad(ssh, index, section)

    unless success
      log_debug "Unable to click the ad button. May be due to fauly view from app switching"
      return
    end
    @has_switched = true

    link_contents = get_link(ssh)

    log_debug "Got contents: #{link_contents}"

    press_screen(ssh, x: 5, y: 5) # press the return to Facebook button (iOS 9 only)
    sleep 1 # let fb load
    run_command(ssh, "killall AppStore", 'kill the AppStore')

    results_info = {}
    results_info.merge!(take_ad_screenshot(ssh, section, index))
    results_info.merge!(take_ad_info_screenshot(ssh, section, index))
    results_info[:link_contents] = link_contents
    results_info[:feed_index] = index
    results_info
  end

  # returns true if clicked ad, false if unable (gracefully)
  def click_ad(ssh, index, section)
    # template the file
    filename = File.join(SCRIPTS_PREFIX, "select_item_#{section}_#{index}.cy")

    scroll_to_item(ssh, index, top: false)
    # run_command(ssh, "cat #{infile} | sed -e s/\\\$1/#{index}/ -e s/\\\$0/#{section}/ > #{outfile}", 'Template the click ad script')

    button_attempts_without_failure = 2
    attempts = 0
    success = false
    resp = nil

    log_debug "Trying to press button"

    while attempts < button_attempts_without_failure && !success

      log_debug "Attempt #{attempts}"
      resp = run_command(ssh, "cycript -p Facebook #{filename}", 'run the click ad file')

      log_debug "Button press response: #{resp.chomp}"

      if resp.match(/Error:/i)
        log_debug "Failed to press button: #{resp.chomp}"
        return false
      end

      sleep 4

      verify = run_command(ssh, 'ps aux | grep AppStore | grep -v grep | wc -l', 'See if AppStore is running')
      success = true if verify.include?('1')
      attempts += 1
    end

    unless success
      if @has_switched
        return false # sometimes after switching, cells are in weird state
      else
        raise "AppStore did not open after clicking ad"
      end
    end

    log_debug "Finished pressing button"

    # Bind the utilities to the app store
    run_command(ssh, "cycript -p AppStore #{File.join(SCRIPTS_PREFIX, 'fb_utilities.cy')}", 'Bind utilities to the AppStore')

    true
  end

  def get_link(ssh)
    # click the share button at the top

    log_debug "Trying to press Share button"
    i = 0
    max_attempts = 3
    pressed = false
    resp = nil

    while i < max_attempts && !pressed
      log_debug "Attempt #{i}"
      resp = run_file(ssh, 'AppStore', 'click_share.cy')
      pressed = true if command_success?(resp)
      i += 1
      sleep 2
    end

    raise resp unless pressed

    log_debug "Pressed share"
    sleep 1 # let the menu option show

    # select the copy link button
    press_coordinates_from_file(ssh, 'get_copy_link_coordinates.cy', 'AppStore')
    sleep 1 # let menu board go away

    # resp = run_command(ssh, "cycript -p AppStore #{File.join(SCRIPTS_PREFIX, 'select_copy_link.cy')}", 'Press the copy link button')

    # raise resp unless resp.match(/Pressed/i)
    # log_debug "Pressed copy"

    # Get the pasteboard contents
    resp = run_command(ssh, "cycript -p AppStore #{File.join(SCRIPTS_PREFIX, 'get_clipboard_contents.cy')}", 'Get the clipboard contents').chomp

    raise "Did not get clipboard contents: #{resp}" if resp.nil? || resp.match(/Error:/i)

    resp
  end

  # takes the screenshots, moves to local computer with unique id, returns a hash with information
  def take_ad_screenshot(ssh, section, index)

    scroll_to_item(ssh, index)

    resp = run_command(ssh, "cycript -p Facebook #{File.join(SCRIPTS_PREFIX, 'hide_tab_bar.cy')}", 'Hide the tab bar')

    raise resp unless command_success?(resp)

    log_debug "Hid Bar"

    outfile = take_screenshot(ssh, 'FB_CREATIVE')

    resp = run_command(ssh, "cycript -p Facebook #{File.join(SCRIPTS_PREFIX, 'show_tab_bar.cy')}", 'Hide the tab bar')

    raise resp unless command_success?(resp)

    log_debug "Show Bar"
    {
      ad_image_path: outfile
    }
  end

  def take_ad_info_screenshot(ssh, section, index)

    log_debug "Taking ad info screenshot"
    scroll_to_item(ssh, index)

    run_and_validate_success(ssh, 'Facebook', "press_ad_options_#{section}_#{index}.cy")
    sleep 0.5

    run_and_validate_success(ssh, 'Facebook', 'select_ad_explanation.cy')
    sleep 4 # takes a while to load web view

    run_and_validate_success(ssh, 'Facebook', 'validate_ad_info_visible.cy')

    outfile = take_screenshot(ssh, 'FB_AD_INFO')
    html_content = run_file(ssh, 'Facebook', 'get_ad_info_html.cy')

    html_content = nil if known_command_error?(html_content)

    run_and_validate_success(ssh, 'Facebook', 'navigate_back_from_preferences.cy')
    sleep 1

    {
      ad_info_image_path: outfile,
      ad_info_html: html_content
    }
  end

  # takes screenshot, moves to local computer and returns the path
  def take_screenshot(ssh, image_prefix)
    resp = run_command(ssh, "cycript -p SpringBoard #{File.join(SCRIPTS_PREFIX, 'take_screenshot.cy')}", 'Take the screenshot')
    sleep 2 # let the screenshot get stored

    raise resp unless command_success?(resp)

    image_path = run_command(ssh, "./#{File.join(SCRIPTS_PREFIX, 'get_recent_image_path.sh')}", 'take screenshot').chomp

    raise "No image available" if image_path.nil?

    log_debug "Copying image"

    outfile = File.join('/tmp', "#{image_prefix}_#{@device.id}_#{image_path.split('/').last}")

    `/usr/local/bin/sshpass -p #{DEVICE_PASSWORD} scp #{DEVICE_USERNAME}@#{@device.ip}:#{image_path} #{outfile}`

    raise "Image failed to copy over" unless 

    # validate
    resp = `[ -f #{outfile} ] && echo 'exists' || echo 'dne'`.chomp
    raise "Failed to scp image file" unless resp.include?('exists')

    outfile
  end

  def log_in(ssh)
    log_debug "Logging in user"

    raise "No FB Account" unless @fb_account.present?

    # Ensure no one is currently logged in

    log_debug "Ensuring no account is logged in"

    raise "An account is already logged in" if is_logged_in?(ssh)

    # template the file
    infile = File.join(SCRIPTS_PREFIX, 'log_in.tmp.cy')
    outfile = File.join(SCRIPTS_PREFIX, 'log_in.cy')
    run_command(ssh, "cat #{infile} | sed -e s/\\\$0/#{@fb_account.username}/ -e s/\\\$1/#{@fb_account.password}/ > #{outfile}", 'Templating log in file')

    # run it
    resp = run_command(ssh, "cycript -p Facebook #{outfile}", 'Running log in file').chomp

    raise "Failed with message: #{resp}" unless resp.match(/Pressed/i)
    sleep 7 # Let the request get sent

    # verify
    log_debug "Verifying log in"

    raise "Failed to log in" unless is_logged_in?(ssh)

    log_debug "Success!"
  end

  # logs out. Intelligently checks to ensure log out is necessary
  def log_out(ssh)

    # ensure FB is open and logged in
    log_debug "Logging out"
    return unless is_logged_in?(ssh)

    # Navigate through the log out sections
    navigate_files = %w(press_more.cy scroll_to_logout.cy press_logout.cy)
    navigate_files.each do |file|
      run_and_validate_success(ssh, 'Facebook', file)
      sleep 1.5 # let the view load
    end

    confirm_logout(ssh)
    sleep 1.5

    raise "Failed to log out" if is_logged_in?(ssh)
  end

  # checks if logged in and opens fb
  def is_logged_in?(ssh)
    log_debug "Checking if logged in"
    open_fb(ssh)
    sleep 2
    resp = run_file(ssh, 'Facebook', 'is_logged_in.cy')
    resp.match(/True/i)
  end

  def press_coordinates_from_file(ssh, filename, app)
    coordinates = run_file(ssh, app, filename)

    coordinates_json = nil
    begin
      coordinates_json = JSON.parse(coordinates)
    rescue
      raise "Could not parse coordinates json with contents: #{coordinates}"
    end

    press_screen(ssh, x: coordinates_json['x'], y: coordinates_json['y'])
  end

  def delete_screenshots(ssh)
    log_debug "Deleting screenshots"
    image_count = run_command(ssh, "find #{IMAGE_FOLDER_PATH} -mindepth 1 | wc -l", 'Get image count').chomp

    if image_count == '0'
      log_debug "No images to delete"
      return
    end

    log_debug "Attempting to delete #{image_count} images"

    log_debug "Opening Photos"
    open_app(ssh, :photos)
    sleep 1

    log_debug "Pressing Albums"

    run_and_validate_success(ssh, 'MobileSlideShow', 'press_albums.cy')
    sleep 0.25


    log_debug "Selecting Camera Roll"

    run_and_validate_success(ssh, 'MobileSlideShow', 'select_camera_roll.cy')
    sleep 0.25

    log_debug "Checking for Photos in Camera Roll available to delete"

    resp = run_file(ssh, 'MobileSlideShow', 'check_for_selectable_photos.cy')

    if command_success?(resp)
      log_debug "Found #{resp.split(':').last.strip} photos to delete"

      log_debug "Scrolling to top of Camera"

      run_and_validate_success(ssh, 'MobileSlideShow', 'scroll_to_top_of_photos.cy')
      sleep 0.25

      log_debug "Pressing Select Mode"

      # resp = run_command(ssh, "cycript -p MobileSlideShow #{File.join(SCRIPTS_PREFIX, 'press_select_mode.cy')}", 'Select Camera Roll')
      # raise resp unless command_success?(resp)
      press_screen(ssh, x: 25, y: 25, orientation: 3) # cheating...it's in the upper right hand corner
      sleep 0.25

      "Getting available coordinates"
      resp = run_file(ssh, 'MobileSlideShow', 'get_photo_coordinates.cy')
      coordinates = nil
      begin
        coordinates = JSON.parse(resp.chomp)
      rescue
        raise "Could not parse coordinates list with contents #{resp}"
      end

      coordinates.each do |coordinate|
        x = coordinate['x']
        y = coordinate['y']
        log_debug "Trying to press (#{x}, #{y})"
        press_screen(ssh, x: x, y: y)
        sleep 0.1
      end


      log_debug "Pressing Trash"
      press_screen(ssh, x: 10, y: 10, orientation: 2) # cheating...we know it's in the bottom right corner
      sleep 0.25

      log_debug "Confirming Delete"
      confirm_photo_delete(ssh)
      sleep 0.5 # let the photos move
    end

    log_debug "Return to Album Screen"
    press_screen(ssh, x: 25, y: 25) # cheating...upper left in nav
    sleep 1 # let the recently deleted album populate

    log_debug "Press Recently Deleted"
    resp = run_file(ssh, 'MobileSlideShow', 'select_recently_deleted.cy')
    sleep 1

    log_debug "Press Select"
    press_screen(ssh, x: 25, y: 25, orientation: 3) # cheating...upper right
    sleep 0.25

    log_debug "Press Delete All"
    press_screen(ssh, x:25, y: 25, orientation: 4) # cheating...lower left
    sleep 0.5 # wait for pop up to render

    log_debug "Confirming Permanent Delete"
    confirm_photo_delete(ssh)
    sleep 1

    run_command(ssh, 'killall MobileSlideShow', 'Killing Photos app')
  end

  def confirm_photo_delete(ssh)

    # verify_command = "cycript -p MobileSlideShow #{File.join(SCRIPTS_PREFIX, 'confirm_delete_coordinates.cy')}"

    # 2.times do |n|
    #   log_debug "Attempt #{n}"
    #   press_coordinates_from_file(ssh, 'confirm_delete_coordinates.cy', 'MobileSlideShow')
    #   sleep 0.25
    #   resp = run_command(ssh, verify_command, 'Check transition view dismissed')
    #   return if known_command_error?(resp) # Should error...cannot find coordinates
    # end

    # raise "Failed to confirm delete"

    confirm_submit_alert_action(ssh, 'MobileSlideShow', 'confirm_delete_coordinates.cy', 'confirm_delete_coordinates.cy')
  end

  def confirm_logout(ssh)
    confirm_submit_alert_action(ssh, 'Facebook', 'get_confirm_logout_coordinates.cy', 'get_confirm_logout_coordinates.cy')
  end

  def confirm_submit_alert_action(ssh, app, coordinates_file, verify_file)
    2.times do |n|
      log_debug "Attempt #{n}"
      press_coordinates_from_file(ssh, coordinates_file, app)
      sleep 2 # confirming an alert action normally triggers a large UI change 
      resp = run_file(ssh, app, verify_file)
      return if known_command_error?(resp) # Should error...cannot find coordinates
    end

    raise "Failed to confirm alert view from app #{app}"
    log_debug "Successfully confirmed alert action"
  end

  def known_command_error?(resp)
    resp.match(/Error:/)
  end
  def command_success?(resp)
    resp.match(/Success/)
  end

  def open_app(ssh, app)
    key = {
      facebook: {
        name: 'Facebook',
        bundle_id: 'com.facebook.Facebook'
      },
      photos: {
        name: 'MobileSlideShow',
        bundle_id: 'com.apple.mobileslideshow'
      }
    }

    info = key[app]

    raise "#{app} is not recognized" if info.nil?

    run_command(ssh, "killall #{info[:name]}", "Ensure #{info[:name]} is closed")
    sleep 1
    run_command(ssh, "open #{info[:bundle_id]}", "Open the #{info[:name]} app")
    sleep 1
    run_command(ssh, "cycript -p #{info[:name]} #{File.join(SCRIPTS_PREFIX, 'fb_utilities.cy')}", "Bind the utilities to #{info[:name]}")
  end

  def teardown(ssh)
    log_debug "Teardown"
    delete_screenshots(ssh)

    run_command(ssh, 'killall Facebook MobileSlideShow AppStore', 'Close Facebook')
    run_command(ssh, 'killall MobileSlideShow', 'Close Photos')
    run_command(ssh, 'killall AppStore', 'Close Photos')
    # run_command(ssh, 'rm -rf ios_fb_scripts *.cy', 'Remove cycript scripts')
    run_command(ssh, 'rm -rf *.cy', 'Remove cycript scripts')
  end

  def run_and_validate_success(ssh, app, filename)
    resp = run_file(ssh, app, filename)
    raise resp unless command_success?(resp)
    resp
  end

  def run_file(ssh, app, filename)
    run_command(ssh, "cycript -p #{app} #{File.join(SCRIPTS_PREFIX, filename)}", "Run file #{filename} on #{app}")
  end

end