# frozen_string_literal: true

require 'test_helper'

# A query parameter is whatever the URL says it is, including an array. The docs app compares it
# against its allowlist as a string, so an unexpected shape is the default rather than a 500.
class DocsParamsTest < ActionDispatch::IntegrationTest
  test 'an array locale param renders the page in the default locale' do
    get '/', params: { locale: ['fr'] }

    assert_response :ok
    assert_select 'html[lang=en]'
  end

  test 'a known locale param still switches the locale' do
    get '/', params: { locale: 'fr' }

    assert_response :ok
    assert_select 'html[lang=fr]'
  end

  test 'an array position param opens the default modal' do
    get '/demos/modal', params: { position: ['x'] }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :ok
    assert_no_match(/modal-right-hidden/, response.body)
  end

  test 'a known position param still opens that modal' do
    get '/demos/modal', params: { position: 'right' }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :ok
    assert_includes response.body, 'modal-right-hidden'
  end
end
