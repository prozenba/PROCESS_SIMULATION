def model_call(path_in,path_out,model, dataset, debug):
 
    import xgboost
    import pandas as pd
    import math
    import category_encoders as ce
    
    if  dataset.endswith(".sas7bdat")  > 1:
        ds_path=path_in+dataset
    else : 
        ds_path=path_in+dataset+".sas7bdat"
        
    model_path=path_in+model
    out_path=path_out+"outscore.csv"

    if debug ==1:
        print ("path: "+path_in) 
        print ("model name: " +model)
        print ("dataset name: " +dataset)
        print("DS_path: " +ds_path)

    target_name='default12'
    time_name='period'
    intercept_name='Intercept'
    event_value='outstanding_bad'
    all_value='outstanding'
    id_vars=['aid']    
    
    df = pd.read_sas(ds_path, encoding='LATIN2')
    
    df[intercept_name]=1
    df[event_value]=df['app_loan_amount']*df[target_name]
    df[all_value]=df['app_loan_amount']
    
    #List of variables
    vars = [var for var in list(df) if var[0:3].lower() in ['app','act']]
    # vars = [var for var in list(df) if var[0:3].lower() in ['app','act','agr','ags']]

    #Splitting into numeric and character variables
    varsc = list(df[vars].select_dtypes(include='object'))
    varsn = list(df[vars].select_dtypes(include='number'))
    
    
    #Categorical variables coding
    enc = ce.BinaryEncoder(cols=varsc)
    df_ce = enc.fit_transform(df[varsc])
    varsc_ce = list(df_ce)

#     df_ce = enc.fit_transform(df)
    df_ce=df

    vars_ce = varsn
#     vars_ce = varsn + varsc_ce

    test = df_ce
    test[target_name]=1

    X_test=test[vars_ce]
    Y_test=test[target_name]

    
    if debug ==1:    
        print (test.shape)
        print (df.shape)

    xdm_test  = xgboost.DMatrix(X_test, Y_test, enable_categorical=True, missing=True)
    
        
    model = xgboost.Booster()

    model.load_model(model_path)

    Y_pred_test = model.predict(xdm_test)
    
    df_out=df

    df_out['SCORECARD_POINTS']= pd.DataFrame(Y_pred_test)
    
    fin_vars= ['SCORECARD_POINTS'] + [time_name] + id_vars
    
    df_out=df_out[fin_vars]
    
    df_out.to_csv(out_path, index=False)
   
        
    return 0