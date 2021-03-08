# frozen_string_literal: true

Rails.configuration.action_mailer.smtp_settings = Rails.config.safe(:smtp).as_json
