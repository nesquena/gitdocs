# -*- encoding : utf-8 -*-

ENV['RACK_ENV'] = 'test'
require File.expand_path('../test_helper', __FILE__)
require 'rack/test'

describe Gitdocs::BrowserApp do
  include Rack::Test::Methods
  def app
    Gitdocs::BrowserApp
  end

  describe 'get /' do
    describe 'with one share' do
      before do
        Gitdocs::Share.stubs(:all).returns([:one])
        Gitdocs::Share.stubs(:first).returns(stub(id: :id))

        get '/'
      end
      specify do
        last_response.status.must_equal(302)
        last_response.headers['Location'].must_equal('http://example.org/id/')
      end
    end

    describe 'with multiple shares' do
      before do
        Gitdocs::Share.stubs(:all).returns(
          [
            stub(id: :id1, path: :path1),
            stub(id: :id2, path: :path2)
          ]
        )

        get '/'
      end
      specify do
        last_response.status.must_equal(200)
        last_response.body.must_include('Select a share to browse')
        last_response.body.must_include('id1')
        last_response.body.must_include('path1')
        last_response.body.must_include('id2')
        last_response.body.must_include('path2')
      end
    end
  end

  describe 'get /search' do
    before do
      Gitdocs::Search.stubs(:search).with('term').returns(results)

      get '/search', q: 'term'
    end

    describe 'empty' do
      let(:results) { {} }
      specify do
        last_response.status.must_equal(200)
        last_response.body.must_include('Matches for &quot;term&quot;')
        last_response.body.must_include('No results')
      end
    end

    describe 'not empty' do
      let(:results) do
        descriptor1    = stub(name: 'repo1', index: 'index1')
        search_result1 = stub(file: 'filename1', context: 'context1')
        descriptor2    = stub(name: 'repo2', index: 'index2')
        search_result2 = stub(file: 'filename2', context: 'context2')

        {
          descriptor1 => [search_result1],
          descriptor2 => [search_result2]
        }
      end
      specify do
        last_response.status.must_equal(200)
        last_response.body.must_include('Matches for &quot;term&quot;')
        last_response.body.must_include('repo1')
        last_response.body.must_include('/index1/filename1')
        last_response.body.must_include('context1')
        last_response.body.must_include('repo2')
        last_response.body.must_include('/index2/filename2')
        last_response.body.must_include('context2')
      end
    end
  end

  describe 'resource methods' do
    let(:repository)      { stub(root: 'root_path') }
    let(:repository_path) { stub }
    before do
      Gitdocs::Share.stubs(:find)
        .with(1234)
        .returns(share = stub)
      Gitdocs::Repository.stubs(:new)
        .with(share)
        .returns(repository)
      Gitdocs::Repository::Path.stubs(:new)
        .with(repository, '/path1/path2')
        .returns(repository_path)
    end

    describe 'get /:id' do
      describe 'meta' do
        before do
          repository_path.stubs(:meta).returns(key: :value)

          get '/1234/path1/path2', mode: 'meta'
        end
        specify do
          last_response.status.must_equal(200)
          last_response.content_type.must_equal('application/json')
          last_response.body.must_equal('{"key":"value"}')
        end
      end

      describe 'edit' do
        before do
          repository_path.stubs(text?: text, content: :content)

          get '/1234/path1/path2', mode: 'edit'
        end

        describe 'not text' do
          let(:text) { false }
          specify { last_response.status.must_equal(404) }
        end

        describe 'text' do
          let(:text) { true }
          specify do
            last_response.status.must_equal(200)
            last_response.body.must_include('content')
          end
        end
      end

      describe 'revisions' do
        before do
          repository_path.stubs(revisions: revisions)

          get '/1234/path1/path2', mode: 'revisions'
        end

        describe 'none' do
          let(:revisions) { [] }
          specify do
            last_response.status.must_equal(200)
            last_response.body.must_include('No revisions for this file could be found.')
          end
        end

        describe 'some' do
          let(:revisions) do
            [
              {
                commit:  'DEADBEEF',
                subject: 'I am a commit',
                author:  'Author <author@example.com>',
                date:    Time.parse('2016-01-01')
              }
            ]
          end
          specify do
            last_response.status.must_equal(200)
            last_response.body.must_include('DEADBEEF')
            last_response.body.must_include('?revision=DEADBEEF')
            last_response.body.must_include('I am a commit')
            last_response.body.must_include('Author <author@example.com>')
            last_response.body.must_include(Time.parse('2016-01-01').iso8601)
          end
        end
      end

      describe 'raw' do
        before do
          repository_path.stubs(absolute_path: :absolute_path)
          app.any_instance.stubs(:send_file).with(:absolute_path)

          get '/1234/path1/path2', mode: 'raw'
        end
        specify { last_response.status.must_equal(200) }
      end

      describe 'simple show' do
        describe 'directory' do
          before do
            repository_path.stubs(
              directory?:   directory,
              readme_path:  :readme_path,
              file_listing: file_listing
            )
            app.any_instance.stubs(:file_content_render)
              .with(:readme_path)
              .returns(:readme_content)

            get '/1234/path1/path2'
          end

          describe 'empty' do
            let(:directory)    { true }
            let(:file_listing) { [] }
            specify do
              last_response.status.must_equal(200)
              last_response.body.must_include('No files were found in this directory.')
              last_response.body.must_include('readme_content')
            end
          end

          describe 'non-empty' do
            let(:directory) { true }
            let(:file_listing) do
              [
                stub(name: 'filename',  is_directory: false),
                stub(name: 'directory', is_directory: true)
              ]
            end
            specify do
              last_response.status.must_equal(200)
              last_response.body.must_include('/img/file.png')
              last_response.body.must_include('filename')
              last_response.body.must_include('/img/folder.png')
              last_response.body.must_include('directory')
              last_response.body.must_include('readme_content')
            end
          end
        end

        describe 'file' do
          before do
            repository_path.stubs(directory?: false)
            repository_path.stubs(:absolute_path)
              .with('revision')
              .returns(:revision_path)
            app.any_instance.stubs(:file_content_render)
              .with(:revision_path)
              .returns(:content)

            get '/1234/path1/path2', revision: 'revision'
          end
          specify do
            last_response.status.must_equal(200)
            last_response.body.must_include('content')
          end
        end
      end
    end

    describe 'post /:id' do
      before { repository_path.stubs(relative_path: 'path1/path2/new') }

      describe 'upload' do
        before do
          repository_path.stubs(absolute_path: :absolute_path)
          repository_path.expects(:join).with(File.basename(__FILE__))
          FileUtils.expects(:mv)
            .with(regexp_matches(/RackMultipart/), :absolute_path)

          post '/1234/path1/path2', file: Rack::Test::UploadedFile.new(__FILE__, 'text/plain')
        end
        specify do
          last_response.status.must_equal(302)
          last_response.headers['Location'].must_equal('http://example.org/1234/path1/path2/new')
        end
      end

      describe 'empty file' do
        before do
          repository_path.expects(:join).with('new')
          repository_path.expects(:touch)

          post '/1234/path1/path2', filename: 'new', new_file: 'value'
        end
        specify do
          last_response.status.must_equal(302)
          last_response.headers['Location'].must_equal('http://example.org/1234/path1/path2/new?mode=edit')
        end
      end

      describe 'directory' do
        before do
          repository_path.expects(:join).with('new')
          repository_path.expects(:mkdir)

          post '/1234/path1/path2', filename: 'new', new_directory: 'value'
        end
        specify do
          last_response.status.must_equal(302)
          last_response.headers['Location'].must_equal('http://example.org/1234/path1/path2/new')
        end
      end
    end

    describe 'put /:id' do
      before { repository_path.stubs(relative_path: 'path1/path2') }

      describe 'update and commit' do
        before do
          repository_path.expects(:write).with('data')
          repository.expects(:write_commit_message).with('message')

          put '/1234/path1/path2', data: 'data', message: 'message'
        end
        specify do
          last_response.status.must_equal(302)
          last_response.headers['Location'].must_equal('http://example.org/1234/path1/path2')
        end
      end

      describe 'revert' do
        before do
          repository_path.expects(:revert).with('revision')
          repository_path.stubs(relative_path: 'path1/path2')
          repository.expects(:write_commit_message).with("Reverting 'path1/path2' to revision")

          put '/1234/path1/path2', revision: 'revision'
        end
        specify do
          last_response.status.must_equal(302)
          last_response.headers['Location'].must_equal('http://example.org/1234/path1/path2')
        end
      end
    end

    describe 'delete /:id' do
      before do
        repository_path.expects(:remove)
        repository_path.stubs(relative_path: 'path1/path2')

        delete '/1234/path1/path2'
      end
      specify do
        last_response.status.must_equal(302)
        last_response.headers['Location'].must_equal('http://example.org/1234/path1')
      end
    end
  end
end
