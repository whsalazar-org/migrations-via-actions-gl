class PseudoExporter
  attr_accessor :model

  def initialize(model)
    self.model = model
  end

  def current_export
    @current_export ||= GlExporter.new
  end

  def renumber!(iid)
    model["iid"] = iid
  end

  def iid
    model["iid"]
  end

  def created_at
    model["created_at"]
  end
end

class PseudoModel < Hash
end
