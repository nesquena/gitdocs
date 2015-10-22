# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'browse and edit repository file through the UI' do
  before do
    gitdocs_add('repo1')
    gitdocs_add('local')

    # Create the various commits, to be able to see revisions.
    GitFactory.commit(:local, 'file1', 'fbadbeef')
    GitFactory.commit(:local, 'file1', 'foobar')
    GitFactory.commit(:local, 'file1', 'deadbeef')
    GitFactory.commit(:local, 'file2', 'A5A5A5A5')
    GitFactory.commit(:local, 'README.md', 'hello i am a README')

    gitdocs_start
    visit_and_click_link('Home')

    within('table#shares') do
      within('tbody') do
        click_link(abs_current_dir('local'))
      end
    end
  end

  it 'should show the README' do
    page.must_have_content('hello i am a README')
  end

  it 'should browse text files' do
    within('table#fileListing') do
      within('tbody') do
        page.must_have_css('tr', count: 3)
        click_link('file1')
      end
    end

    page.must_have_content('deadbeef')
  end

  # TODO: it 'should browse non-text files' do
  # TODO: it 'should view raw file' do

  describe 'revisions' do
    before do
      within('table#fileListing') { within('tbody') { click_link('file1') } }
      click_link('Revisions')
    end

    it 'should be able to browser a file revision' do
      # FIXME: This test is failing on TravisCI, but succeeding locally so skip
      # it for now and revisit in the future.
      next if ENV['TRAVIS']

      within('table#revisions') do
        within('tbody') do
          page.must_have_css('tr', count: 2)
          within(:xpath, '//tr[2]') do
            within('td.commit') do
              find('a').click
            end
          end
        end
      end
      page.must_have_content('foobar')
    end

    it 'should allow file revert' do
      # FIXME: This test is failing on TravisCI, but succeeding locally so skip
      # it for now and revisit in the future.
      next if ENV['TRAVIS']

      within('table#revisions') do
        within('tbody') do
          page.must_have_css('tr', count: 2)
          within(:xpath, '//tr[2]') do
            within('td.revert') do
              find('input.btn').click
            end
          end
        end
      end
      page.must_have_content('foobar')
    end
  end

  it 'should edit text files' do
    within('table#fileListing') { within('tbody') { click_link('file1') } }
    click_link('Edit')

    within('form.edit') do
      within('#editor') do
        find('textarea').set('foobar')
      end
      fill_in('message', with: 'commit message')
      click_button('Save')
    end

    page.must_have_content('foobar')
  end

  describe 'creation' do
    it 'should allow directory creation' do
      within('form.add') do
        fill_in('filename', with: 'new_directory')
        click_button('directory')
      end
      within('h2') { page.must_have_content('/new_directory') }
      page.must_have_content('No files were found in this directory.')
    end

    it 'should allow file creation' do
      within('form.add') do
        fill_in('filename', with: 'new_file')
        click_button('file')
      end

      within('h2') { page.must_have_content('/new_file') }
      within('form.edit') do
        within('#editor') do
          find('textarea').set('foobar')
        end
        fill_in('message', with: 'commit message')
        click_button('Save')
      end

      page.must_have_content('foobar')
    end

    # TODO: it 'should allow file upload' do
  end

  it 'should allow file deletion' do
    within('table#fileListing') { within('tbody') { click_link('file1') } }
    click_on('Delete')
    within('table#fileListing') do
      within('tbody') do
        page.must_have_css('tr', count: 2)
        page.wont_have_content('file1')
        page.must_have_content('file2')
      end
    end
  end
end
