require_relative 'test_helper'

# Public-facing pages, including that the removed features stay removed.
class PublicPagesTest < Minitest::Test
  include TestHelpers

  def test_home_page_renders
    get '/'
    assert last_response.ok?
    assert_includes last_response.body, 'Roberts'
    assert_includes last_response.body, 'Ginesi'
  end

  def test_home_page_has_no_countdown_timer
    get '/'
    refute_includes last_response.body, 'id="countdown"'
    refute_includes last_response.body, 'id="cd-days"'
  end

  def test_home_page_has_no_accommodations
    get '/'
    refute_includes last_response.body, 'id="accommodations"'
    refute_includes last_response.body, 'Accommodations'
  end

  def test_registry_page_renders
    get '/registry'
    assert last_response.ok?
  end
end

# RSVP is disabled by default (wedding is over).
class RsvpDisabledTest < Minitest::Test
  include TestHelpers

  def setup
    ENV.delete('RSVP_ENABLED')
  end

  def test_get_rsvp_returns_404
    get '/rsvp'
    assert_equal 404, last_response.status
  end

  def test_get_rsvp_success_returns_404
    get '/rsvp/success'
    assert_equal 404, last_response.status
  end

  def test_get_rsvp_with_code_returns_404
    get '/rsvp/ABC123'
    assert_equal 404, last_response.status
  end

  def test_post_rsvp_returns_404
    post '/rsvp', name: 'Test Guest', attending: 'yes'
    assert_equal 404, last_response.status
  end

  def test_post_rsvp_does_not_write_to_db
    before = DB[:rsvps].count
    post '/rsvp', name: 'Test Guest', attending: 'yes'
    assert_equal before, DB[:rsvps].count
  end
end

# RSVP can be turned back on for a demo via RSVP_ENABLED=true.
class RsvpEnabledTest < Minitest::Test
  include TestHelpers

  def setup
    ENV['RSVP_ENABLED'] = 'true'
  end

  def teardown
    ENV.delete('RSVP_ENABLED')
  end

  def test_get_rsvp_renders_form
    get '/rsvp'
    assert last_response.ok?
  end

  def test_get_rsvp_with_unknown_code_returns_404
    get '/rsvp/does-not-exist'
    assert_equal 404, last_response.status
  end

  def test_get_rsvp_with_known_code_renders
    DB[:guests].insert(name: 'Known Guest', code: 'KNOWN1')
    get '/rsvp/KNOWN1'
    assert last_response.ok?
  ensure
    DB[:guests].where(code: 'KNOWN1').delete
  end

  def test_post_rsvp_creates_record_and_redirects
    before = DB[:rsvps].count
    post '/rsvp', name: 'Jane Doe', attending: 'yes', meal_choice: 'Chicken'
    assert last_response.redirect?
    assert_includes last_response.headers['Location'], '/rsvp/success'
    assert_equal before + 1, DB[:rsvps].count
  ensure
    DB[:rsvps].where(name: 'Jane Doe').delete
  end
end

# Admin authentication and dashboard.
class AdminTest < Minitest::Test
  include TestHelpers

  def test_admin_requires_login
    get '/admin'
    assert last_response.redirect?
    assert_includes last_response.headers['Location'], '/admin/login'
  end

  def test_admin_login_page_renders
    get '/admin/login'
    assert last_response.ok?
  end

  def test_admin_login_with_wrong_password_shows_error
    post '/admin/login', password: 'definitely-wrong'
    assert last_response.ok?
    assert_includes last_response.body, 'Invalid password'
  end

  def test_admin_login_grants_access_to_dashboard
    post '/admin/login', password: ENV.fetch('ADMIN_PASSWORD', 'admin')
    assert last_response.redirect?
    follow_redirect!
    assert last_response.ok?
  end
end
