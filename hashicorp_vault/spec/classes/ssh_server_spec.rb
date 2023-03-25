# frozen_string_literal: true

require 'spec_helper'

describe 'hashicorp_vault::ssh_server' do
  on_supported_os.each do |os, os_facts|
    ['vault_public_key', 'vault_ssh_engine'].each do |key_source|
      context "on #{os}" do
        let(:facts) { os_facts }
        let(:params) {
          {
            'vault_server' => "https://vault.example.com",
            key_source => 'example key'
          }
        }

        it { is_expected.to compile }
      end
    end
  end
end
