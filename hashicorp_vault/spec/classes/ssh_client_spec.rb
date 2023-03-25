# frozen_string_literal: true

require 'spec_helper'

describe 'hashicorp_vault::ssh_client' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) {
        {
          'vault_server' => "https://vault.example.com",
          'auth_method' => 'ldap'
        }
      }

      it { is_expected.to compile }
    end
  end
end
