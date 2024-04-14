# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# config/importmap.rb
pin 'monaco-editor', to: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/+esm'
pin "bootstrap" # @5.3.3
pin "popper", to: "https://cdn.skypack.dev/@popperjs/core@2.10.2"
pin "@popperjs/core", to: "@popperjs--core.js" # @2.11.8
