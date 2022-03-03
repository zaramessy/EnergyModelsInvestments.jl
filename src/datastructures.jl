
struct StrategicCase <: EMB.Case
    CO2_limit::TS.TimeProfile
    emissions_price::Dict{ResourceEmit, TS.TimeProfile}
end

abstract type AbstractInvestmentModel <: EMB.EnergyModel end

struct InvestmentModel <: AbstractInvestmentModel
    case::StrategicCase
    # Discount rate
    r
end

# struct DiscreteInvestmentModel <: AbstractInvestmentModel
#     case
#     # Discount rate
#     r       
# end
# struct ContinuousInvestmentModel <: AbstractInvestmentModel
#     case
#     # Discount rate
#     r       
# end

# Investment type traits for nodes
abstract type Investment end 					# Kind of investment variables 
struct DiscreteInvestment       <: Investment end 	# Binary variables
struct IntegerInvestment        <: Investment end 	# Integer variables (investments in capacity increments)
struct ContinuousInvestment     <: Investment end 	# Continuous variables
struct SemiContinuousInvestment <: Investment end 	# Semi-Continuous variables
struct FixedInvestment          <: Investment end   # Fixed variables or as parameter
struct IndividualInvestment     <: Investment end 	# Look up property of each node to decide

abstract type Lifetime_mode end
struct Unlimited_Life       <: Lifetime_mode end    # The investment life is not limited. The investment costs do not consider any reinvestment or rest value.
struct Study_Inv            <: Lifetime_mode end    # The investment last for the whole study period with adequate reinvestments at end of lifetime and rest value.
struct Period_Inv           <: Lifetime_mode end    # The investment is considered to last only for the strategic period. The excess lifetime is considered in the rest value.
struct Rolling_Inv          <: Lifetime_mode end    # The investment is rolling to the next strategic periods and it is retired at the end of its lifetime or the the end of the previous sp if its lifetime ends between two sp.

# Define Structure for the additional parameters passed 
# to the technology structures defined in other packages
Base.@kwdef struct extra_inv_data <: EMB.Data
    Capex_Cap::TS.TimeProfile
    Cap_max_inst::TS.TimeProfile
    Cap_max_add::TS.TimeProfile
    Cap_min_add::TS.TimeProfile
    Inv_mode::Investment = ContinuousInvestment()
    Cap_start::Union{Real, Nothing} = nothing
    Cap_increment::TS.TimeProfile = FixedProfile(0)
    # min_inst_cap::TS.TimeProfile #TO DO Implement
    Life_mode::Lifetime_mode = Unlimited_Life()
    Lifetime::TS.TimeProfile = FixedProfile(0)
 end


 Base.@kwdef struct extra_inv_data_storage <: EMB.Data
    #Investment data related to storage power
    Capex_rate::TS.TimeProfile #capex of power
    Rate_max_inst::TS.TimeProfile
    Rate_max_add::TS.TimeProfile
    Rate_min_add::TS.TimeProfile
    #Investment data related to storage capacity
    Capex_stor::TS.TimeProfile #capex of capacity
    Stor_max_inst::TS.TimeProfile
    Stor_max_add::TS.TimeProfile
    Stor_min_add::TS.TimeProfile
    # General inv data
    Inv_mode::Investment = ContinuousInvestment()
    Rate_start::Union{Real, Nothing} = nothing
    Stor_start::Union{Real, Nothing} = nothing
    Rate_increment::TS.TimeProfile = FixedProfile(0)
    Stor_increment::TS.TimeProfile = FixedProfile(0)
    # min_inst_cap::TS.TimeProfile #TO DO Implement
    Life_mode::Lifetime_mode = Unlimited_Life()
    Lifetime::TS.TimeProfile = FixedProfile(0)
 end
#Consider package Parameters.jl to define struct with default values

# """
#     investmentmode(x)

# Return investment mode of node `x`. By default, all investments are continuous.
# Implement specialised methods to add more investment modes, e.g.:
# ## Example
# ```
# investmentmode(::Battery) = DiscreteInvestment()    # Discrete for Battery nodes
# investmentmode(::FuelCell) = IndividualInvestment() # Look up for each FuelCell node
# TO DO SemiContinuous investment mode
# ```

# """
# investmentmode(x) = ContinuousInvestment() 			# Default to continuous


"""
    investmentmode_inst(n)

Return the investment mode of the node 'n'. By default, all investments are continuous (set in the struct
 definition with the kwdef function).
"""

investmentmode(n) = n.Data["InvestmentModels"].Inv_mode
lifetimemode(n) = n.Data["InvestmentModels"].Life_mode

# TO DO function to fetch investment mode from the node type?