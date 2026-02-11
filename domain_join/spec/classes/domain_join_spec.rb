# frozen_string_literal: true

require 'spec_helper'
require 'rspec-puppet'

describe 'domain_join' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { # rubocop:disable Style/BlockDelimiters
        {
          'username' => 'join_user',
          'sensitive_password' => RSpec::Puppet::Sensitive.new('test'),
          'global_admins' => 'EXAMPLE Linux Admins',
          'global_ssh' => 'EXAMPLE Linux SSH Users',
          'local_admins' => 'EXAMPLE %HOSTNAME% Admins',
          'local_ssh' => 'EXAMPLE %HOSTNAME% SSH Users',
          'file_header' => 'OpenVox managed'
        }
      }

      it { is_expected.to compile }
    end
  end
end
