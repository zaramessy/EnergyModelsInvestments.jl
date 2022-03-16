const GEO = Geography

function has_trans_investment(i)
    """For a given transmission, checks that it contains extra data (i.data : list containing the extra data of the different corridor modes ) and that 
    at leat one corridor mode has investment data defined.
     """
    isa(i, GEO.Transmission) && 
    (
        hasproperty(i, :Data) &&
        #!=(Base.unique(i.data), Dict{"InvestmentModels", EMB.EmptyData()}) &&
        #!=(Base.unique([d for d  in i.data if "InvestmentModels" ∈ keys(d)]), Dict{"InvestmentModels", EMB.EmptyData()}) &&
        !=([d for d in i.Data if ("InvestmentModels" ∈ keys(d) && !=(get(d, "InvestmentModels", EMB.EmptyData()), EMB.EmptyData()) )], [])
    )
end

function has_cm_investment(cm,l)
    isa(cm, GEO.TransmissionMode) &&
    isa(l, GEO.Transmission) &&
    cm ∈ l.Modes  &&
    haskey(l.Data[get_cm_index(cm,l)], "InvestmentModels") &&
    (
        hasproperty(l.Data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_max_inst) ||
        hasproperty(l.Data[get_cm_index(cm,l)]["InvestmentModels"], :Capex_trans) ||
        hasproperty(l.Data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_max_add) ||
        hasproperty(l.Data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_min_add)
    )
end

function corridor_modes_with_inv(l)
    return [m for m in l.Modes if ("InvestmentModels" in keys(l.Data[get_cm_index(m,l)])  && !=(l.Data[get_cm_index(m,l)]["InvestmentModels"], EMB.EmptyData))]
end

function get_cm_index(cm,l)
    """ Returns the index of the given corridor mode in the defined transmission """
    findfirst(x -> x==cm, l.Modes)# we assume that all transmission modes have a different name
end