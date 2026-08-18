# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileLanguageMapper do
  before(:example) do
    {
      '.rb' => 'Ruby',
      '.erb' => 'Ruby/Vistas',
      '.haml' => 'Ruby/Vistas',
      '.js' => 'JavaScript/Frontend',
      '.jsx' => 'JavaScript/Frontend',
      '.ts' => 'JavaScript/Frontend',
      '.tsx' => 'JavaScript/Frontend',
      '.vue' => 'JavaScript/Frontend'
    }.each { |extension, tech| FileExtensionMapping.create!(extension: extension, tech: tech) }

    described_class.reload_extension_map!
  end

  it 'recognices Ruby extension' do
    expect(described_class.tech_for('app/models/user.rb')).to eq('Ruby')
  end

  it 'recognices ruby views (erb/haml)' do
    expect(described_class.tech_for('app/views/users/show.html.erb')).to eq('Ruby/Vistas')
  end

  it 'recognices JavaScript/Frontend across several extensions' do
    %w[app.js component.jsx module.ts widget.tsx page.vue].each do |file|
      expect(described_class.tech_for(file)).to eq('JavaScript/Frontend')
    end
  end

  it 'recognices migrations and schema as database' do
    expect(described_class.tech_for('db/migrate/20260101_create_things.rb')).to eq('SQL/Base de datos')
    expect(described_class.tech_for('db/schema.rb')).to eq('SQL/Base de datos')
  end

  it 'recognices Gemfile and Rakefile as Ruby' do
    expect(described_class.tech_for('Gemfile')).to eq('Ruby')
    expect(described_class.tech_for('Rakefile')).to eq('Ruby')
  end

  it 'recognices github workflows as DevOps/Config' do
    expect(described_class.tech_for('.github/workflows/ci.yml')).to eq('DevOps/Config')
  end

  it 'falls back to Otros for unknown extensions' do
    expect(described_class.tech_for('README.md')).to eq('Otros')
  end
end
