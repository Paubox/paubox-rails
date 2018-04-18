class TestMailer < ActionMailer::Base
  default from: 'tester@paubox.com',
          to: 'test@paubox.com',
          subject: 'Test Mailer Subject'

  def text_only_message
    mail
  end
end
