# Default-deny (ADR-0003): every action method here returns false. Concrete
# policies override only the actions their resource actually supports —
# there is no permissive fallback to accidentally inherit.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  def sysadmin?
    user&.role == "sysadmin"
  end

  def same_site?
    user && record.respond_to?(:site_ref) && user.site_ref == record.site_ref
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    def sysadmin?
      user&.role == "sysadmin"
    end
  end
end
