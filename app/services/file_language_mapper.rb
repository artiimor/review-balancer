# frozen_string_literal: true

# Mapea la ruta de un archivo tocado en una PR a una categoría de "tecnología"
# legible para humanos. Deliberadamente simple para el MVP: por extensión y,
# en un par de casos, por convención de carpeta. Nada de detección "inteligente"
# — eso es justo lo que sobra en un v1.
class FileLanguageMapper
  EXTENSION_MAP = {
    '.rb' => 'Ruby',
    '.rake' => 'Ruby',
    '.erb' => 'Ruby/Vistas',
    '.haml' => 'Ruby/Vistas',
    '.slim' => 'Ruby/Vistas',
    '.js' => 'JavaScript/Frontend',
    '.jsx' => 'JavaScript/Frontend',
    '.ts' => 'JavaScript/Frontend',
    '.tsx' => 'JavaScript/Frontend',
    '.vue' => 'JavaScript/Frontend',
    '.css' => 'Frontend/Estilos',
    '.scss' => 'Frontend/Estilos',
    '.py' => 'Python',
    '.sql' => 'SQL/Base de datos',
    '.yml' => 'DevOps/Config',
    '.yaml' => 'DevOps/Config',
    '.tf' => 'DevOps/Config',
    '.dockerfile' => 'DevOps/Config'
  }.freeze

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
    EXTENSION_MAP.fetch(ext, DEFAULT_TECH)
  end
end
