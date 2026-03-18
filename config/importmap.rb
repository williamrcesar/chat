# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "cropperjs", to: "https://cdn.jsdelivr.net/npm/cropperjs@1.6.2/dist/cropper.esm.js"
pin "@100mslive/hms-video-store", to: "https://cdn.skypack.dev/@100mslive/hms-video-store@0.12.0", preload: false
pin_all_from "app/javascript/controllers", under: "controllers"
