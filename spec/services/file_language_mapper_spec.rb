# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileLanguageMapper do
  it 'reconoce Ruby por extensión' do
    expect(described_class.tech_for('app/models/user.rb')).to eq('Ruby')
  end

  it 'reconoce vistas Ruby (erb/haml)' do
    expect(described_class.tech_for('app/views/users/show.html.erb')).to eq('Ruby/Vistas')
  end

  it 'reconoce JavaScript/Frontend en varias extensiones' do
    %w[app.js component.jsx module.ts widget.tsx page.vue].each do |file|
      expect(described_class.tech_for(file)).to eq('JavaScript/Frontend')
    end
  end

  it 'reconoce migraciones y schema como Base de datos, no como Ruby' do
    expect(described_class.tech_for('db/migrate/20260101_create_things.rb')).to eq('SQL/Base de datos')
    expect(described_class.tech_for('db/schema.rb')).to eq('SQL/Base de datos')
  end

  it 'reconoce Gemfile y Rakefile como Ruby aunque no tengan extensión' do
    expect(described_class.tech_for('Gemfile')).to eq('Ruby')
    expect(described_class.tech_for('Rakefile')).to eq('Ruby')
  end

  it 'reconoce workflows de GitHub Actions como DevOps/Config' do
    expect(described_class.tech_for('.github/workflows/ci.yml')).to eq('DevOps/Config')
  end

  it 'cae en Otros para extensiones desconocidas' do
    expect(described_class.tech_for('README.md')).to eq('Otros')
  end
end
