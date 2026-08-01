# frozen_string_literal: true

namespace :file_extension_mappings do
  desc 'Puebla file_extension_mappings con el mapeo por defecto de extensión a tecnología'
  task seed: :environment do
    mappings = {
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
      '.dockerfile' => 'DevOps/Config',
      '.java' => 'Java',
      '.c' => 'C',
      '.h' => 'C',
      '.cpp' => 'C++',
      '.cc' => 'C++',
      '.hpp' => 'C++',
      '.cs' => 'C#',
      '.go' => 'Go',
      '.rs' => 'Rust',
      '.php' => 'PHP',
      '.kt' => 'Kotlin',
      '.kts' => 'Kotlin',
      '.swift' => 'Swift',
      '.sh' => 'Shell'
    }

    mappings.each do |extension, tech|
      FileExtensionMapping.find_or_initialize_by(extension: extension).update!(tech: tech)
    end

    FileLanguageMapper.reload_extension_map!

    puts "Sembradas #{mappings.size} extensiones."
  end
end
