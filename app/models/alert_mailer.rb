class AlertMailer < ActionMailer::Base

  def confirmation(subscriber)
    @recipients   = subscriber.email
    @from         = 'alerts@openlylocal.com'
    @subject      = "OpenlyLocal Alert :: Please confirm your Planning Application subscription"
    @sent_on      = Time.now
    @body[:subscriber] = subscriber
    @headers      = {}
  end
  
  def planning_alert(params={})
    @recipients   = params[:subscriber].email
    @from         = 'alerts@openlylocal.com'
    @subject      = "OpenlyLocal Alert :: New Planning Application: #{params[:planning_application].address}"
    @sent_on      = Time.now
    @body[:planning_application] = params[:planning_application]
    @body[:subscriber] = params[:subscriber]
    @headers      = {}
  end
  
end
