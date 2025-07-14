module VendorApplicationsHelper
  def vendor_status_text(status)
    case status.to_s
    when "pending"
      "申請中"
    when "approved"
      "承認済み"
    when "rejected"
      "却下"
    else
      status.humanize
    end
  end

  def vendor_status_color(status)
    case status.to_s
    when "pending"
      "warning"
    when "approved"
      "success"
    when "rejected"
      "danger"
    else
      "secondary"
    end
  end
end
