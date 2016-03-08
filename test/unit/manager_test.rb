# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'gitdocs manager' do
  describe '.listen_method' do
    subject { Gitdocs::Manager.listen_method }

    before do
      Guard::Listener.stubs(:mac?).returns(mac)
      Guard::Darwin.stubs(:usable?).returns(darwin_usable)
      Guard::Listener.stubs(:linux?).returns(linux)
      Guard::Linux.stubs(:usable?).returns(linux_usable)
      Guard::Listener.stubs(:windows?).returns(windows)
      Guard::Windows.stubs(:usable?).returns(windows_usable)
    end

    describe 'mac polling' do
      let(:mac)     { true }  ; let(:darwin_usable)  { false }
      let(:linux)   { false } ; let(:linux_usable)   { false }
      let(:windows) { false } ; let(:windows_usable) { false }
      it { subject.must_equal :polling }
    end

    describe 'mac notification' do
      let(:mac)     { true }  ; let(:darwin_usable)  { true }
      let(:linux)   { false } ; let(:linux_usable)   { false }
      let(:windows) { false } ; let(:windows_usable) { false }
      it { subject.must_equal :notification }
    end

    describe 'linux polling' do
      let(:mac)     { false } ; let(:darwin_usable)  { false }
      let(:linux)   { true }  ; let(:linux_usable)   { false }
      let(:windows) { false } ; let(:windows_usable) { false }
      it { subject.must_equal :polling }
    end

    describe 'linux notification' do
      let(:mac)     { false } ; let(:darwin_usable)  { false }
      let(:linux)   { true }  ; let(:linux_usable)   { true }
      let(:windows) { false } ; let(:windows_usable) { false }
      it { subject.must_equal :notification }
    end

    describe 'windows polling' do
      let(:mac)     { false } ; let(:darwin_usable)  { false }
      let(:linux)   { false } ; let(:linux_usable)   { false }
      let(:windows) { true }  ; let(:windows_usable) { false }
      it { subject.must_equal :polling }
    end

    describe 'windows notification' do
      let(:mac)     { false } ; let(:darwin_usable)  { false }
      let(:linux)   { false } ; let(:linux_usable)   { false }
      let(:windows) { true }  ; let(:windows_usable) { true }
      it { subject.must_equal :notification }
    end

    describe 'polling' do
      let(:mac)     { false } ; let(:darwin_usable)  { false }
      let(:linux)   { false } ; let(:linux_usable)   { false }
      let(:windows) { false } ; let(:windows_usable) { false }
      it { subject.must_equal :polling }
    end
  end
end
