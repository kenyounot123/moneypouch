require "test_helper"

class DemoModeTest < ActionDispatch::IntegrationTest
  include SimplefinTestHelper

  test "bank sync and imports are not found in the demo" do
    activate(connect_simplefin(users(:one)))
    import = users(:one).start_import(import_file("personal.csv"))
    sign_in_as users(:one)

    with_demo do
      requests = [
        [ :get, new_simplefin_access_path ], [ :post, simplefin_access_path ], [ :get, edit_simplefin_access_path ],
        [ :patch, simplefin_access_path ], [ :delete, simplefin_access_path ], [ :post, simplefin_sync_path ],
        [ :get, simplefin_review_path ], [ :post, simplefin_review_completion_path ],
        [ :patch, bank_account_path(users(:one).bank_accounts.first) ],
        [ :get, new_import_path ], [ :post, imports_path ], [ :delete, import_path(import) ],
        [ :get, edit_import_columns_path(import) ], [ :patch, import_columns_path(import) ],
        [ :get, edit_import_categories_path(import) ], [ :patch, import_categories_path(import) ], [ :post, import_transactions_path(import) ]
      ]

      requests.each do |verb, path|
        send(verb, path)
        assert_response :not_found, "#{verb} #{path}"
      end
    end
  end

  test "the demo never claims a SimpleFIN setup token" do
    sign_in_as users(:one)

    with_demo do
      post simplefin_access_path, params: { simplefin_access: { setup_token: SimplefinTestHelper::SETUP_TOKEN } }
    end

    assert_response :not_found
    assert_nil users(:one).reload.simplefin_access
  end

  test "an import upload is not found in the demo and saves nothing" do
    sign_in_as users(:one)

    assert_no_difference -> { Import.count } do
      with_demo do
        post imports_path, params: { import: { file: import_file("personal.csv") } }
      end
    end

    assert_response :not_found
  end

  test "password resets and the registration switch are not found in the demo, even for the owner" do
    sign_in_as users(:one)
    token = users(:two).password_reset_token

    with_demo do
      post user_password_reset_path(users(:two))
      assert_response :not_found

      patch registration_path, params: { open: true }
      assert_response :not_found

      get edit_password_path(token)
      assert_response :not_found

      patch password_path(token), params: { password: "taken-over", password_confirmation: "taken-over" }
      assert_response :not_found
    end

    assert_not users(:one).reload.registration_open?
    assert users(:two).reload.authenticate("password")
  end

  test "a sandbox's Settings show bank sync as unavailable and nothing for the owner" do
    with_demo do
      post sandbox_path
      get settings_path
    end

    assert_response :success
    assert_select "h2", text: "Bank sync"
    assert_select "span", text: "Not available in the demo"
    assert_select "a[href=?]", new_simplefin_access_path, count: 0
    assert_select "form[action=?]", registration_path, count: 0
    assert_select "a[href=?]", new_import_path, count: 0
  end

  test "a sandbox sees when it is deleted, how to install, and where to send feedback" do
    with_demo do
      post sandbox_path
      follow_redirect!
    end

    assert_select "section[aria-label=Demo]" do
      assert_select "p", text: "This is a demo"
      assert_select "p", text: "Your sandbox is deleted in 24 hours."
      assert_select "a[href=?]", "https://github.com/kenyounot123/moneypouch#getting-started", text: "Install MoneyPouch"
      assert_select "a[href=?]", "https://github.com/kenyounot123/moneypouch/issues/new", text: "Send feedback"
    end
  end

  test "outside the demo there is no demo note" do
    sign_in_as users(:one)

    get root_path

    assert_select "section[aria-label=Demo]", count: 0
  end

  test "outside the demo Settings keep Connect your bank and the sidebar keeps Import" do
    sign_in_as users(:one)

    get settings_path

    assert_select "a[href=?]", new_simplefin_access_path, text: "Connect your bank"
    assert_select "a[href=?]", new_import_path, text: "Import"
    assert_select "span", text: "Not available in the demo", count: 0
  end
end
