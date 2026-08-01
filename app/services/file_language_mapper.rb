# frozen_string_literal: true

class FileLanguageMapper
  PATH_OVERRIDES = [
    [%r{\Adb/migrate/}, 'SQL/Base de datos'],
    [%r{\Adb/schema\.rb\z}, 'SQL/Base de datos'],
    [/\A(Gemfile|Rakefile)\z/, 'Ruby'],
    [/\ADockerfile\z/i, 'DevOps/Config'],
    [%r{\A\.github/workflows/}, 'DevOps/Config']
  ].freeze

  DEFAULT_TECH = 'Otros'

  def self.tech_for(path)
    PATH_OVERRIDES.each do |(pattern, tech)|
      return tech if path.match?(pattern)
    end

    ext = File.extname(path).downcase
    extension_map.fetch(ext, DEFAULT_TECH)
  end

  def self.extension_map
    @extension_map ||= FileExtensionMapping.pluck(:extension, :tech).to_h
  end

  def self.reload_extension_map!
    @extension_map = nil
  end
end
