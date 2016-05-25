# -*- encoding : utf-8 -*-

require File.expand_path('../../test_helper', __FILE__)

describe 'Manage which shares are being watched' do
  it 'should update a share through the UI' do
    gitdocs_add('local')
    gitdocs_start
    visit_and_click_link('Settings')

    within('#settings') do
      within('#share-0') do
        fill_in('share[0][polling_interval]', with: '0.2')
        select('Fetch only', from: 'share[0][sync_type]')
      end
      click_button('Save')
    end

    # Allow the asynchronous portion of the update finish before checking
    # the result.
    sleep(1)

    click_link('Settings')
    within('#settings') do
      within('#share-0') do
        page.must_have_field('share[0][polling_interval]', with: '0.2')
        page.must_have_field('share[0][sync_type]', with: 'fetch')
      end
    end
  end

  describe 'remove a share' do
    before { gitdocs_add('local') }

    it do
      gitdocs_start
      visit_and_click_link('Settings')

      within('#settings') do
        within('#share-0') { click_link('Delete') }

        page.must_have_css('.share', count: 0)
      end
    end
  end
end
