module CapybaraHelpers
  # Throw a one-time load callback on datatables so we can use it to make sure
  # it has finished loading.  Useful for clicking a filter and making sure it's
  # done reloading.
  def with_datatable_load_wait(timeout, &blk)
    execute_script(<<-JSCODE)
      $('.effective-datatable').DataTable().one('draw.dt', function() {
        window['ef_datatables_done_loading'] = true; 
      });
    JSCODE
    blk.call
    wait_for_condition_until(timeout) do
      evaluate_script(<<-JSCODE)
        window['ef_datatables_done_loading'] == true
      JSCODE
    end
    execute_script(<<-JSCODE)
      delete window['ef_datatables_done_loading'];
    JSCODE
  end

  def wait_for_condition_until(timeout, &blk)
    test_val = blk.call
    waited_time = 0
    while((!test_val) && (waited_time < timeout)) do
      sleep 1
      test_val = blk.call
      waited_time = waited_time + 1
    end
  end

  def select_from_chosen(val, from:)
    chosen_input = find 'a.chosen-single'
    chosen_input.click
    chosen_results = find 'ul.chosen-results'
    within(chosen_results) do
      find('li', text: val).click
    end
  end

  def wait_for_ajax(delta=2, time_to_sleep=0.2)
    start_time = Time.now
    Capybara.default_max_wait_time = delta
    Timeout.timeout(Capybara.default_max_wait_time) do
      until finished_all_ajax_requests? do
        sleep(0.01)
      end
    end
    end_time = Time.now
    Capybara.default_max_wait_time = 2
    if Time.now > start_time + delta.seconds
      fail "ajax request failed: took longer than #{delta.seconds} seconds. It waited #{end_time - start_time} seconds."
    end
    puts "Finished helper method after #{end_time - start_time} seconds"
    sleep(time_to_sleep)
  end

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end
end

World(CapybaraHelpers)
