FUNCTION zzfm_fi_001.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_FII001_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_FII001_RESP
*"----------------------------------------------------------------------
  " You can use the template 'functionModuleParameter' to add here the signature!
  .
  DATA:ls_out TYPE zzs_fii001_out.
  DATA:lt_out TYPE zzt_fii001_out.
  DATA(ls_req) = i_req-req.

  DATA:r_bukrs TYPE RANGE OF i_fixedasset-companycode.
  DATA:r_anln1 TYPE RANGE OF i_fixedasset-masterfixedasset.
  DATA:r_anlkl TYPE RANGE OF i_fixedasset-assetclass.
  DATA:r_txt50 TYPE RANGE OF i_fixedasset-fixedassetdescription.
  DATA:r_asset TYPE RANGE OF i_fixedassetassgmt-yy1_asset_fab.

  LOOP AT ls_req-companycode INTO DATA(lv_companycode).
    APPEND VALUE #( sign   = 'I'
                    option = 'EQ'
                    low    = lv_companycode
      ) TO r_bukrs.
  ENDLOOP.
  LOOP AT ls_req-masterfixedasset INTO DATA(lv_masterfixedasset).
    APPEND VALUE #( sign   = 'I'
                    option = 'EQ'
                    low    = |{ lv_masterfixedasset ALPHA = IN }|
      ) TO r_anln1.
  ENDLOOP.
  LOOP AT ls_req-assetclass INTO DATA(lv_assetclass).
    APPEND VALUE #( sign   = 'I'
                    option = 'EQ'
                    low    = lv_assetclass
      ) TO r_anlkl.
  ENDLOOP.
  LOOP AT ls_req-description INTO DATA(lv_description).
    APPEND VALUE #( sign   = 'I'
                    option = 'CP'
                    low    = |*{ lv_description }*|
      ) TO r_txt50.
  ENDLOOP.
  LOOP AT ls_req-assetuser INTO DATA(lv_assetuser).
    APPEND VALUE #( sign   = 'I'
                    option = 'EQ'
                    low    = lv_assetuser
      ) TO r_asset.
  ENDLOOP.

  "分页查询
  DATA(lv_currpage) = i_req-currpage.
  DATA(lv_pagesize) = i_req-pagesize.
  IF lv_currpage = 0.
    lv_currpage = 1.
  ENDIF.
  IF lv_pagesize = 0.
    lv_pagesize = 100.
  ENDIF.


  SELECT a~companycode,
         a~masterfixedasset,
         a~fixedasset,
         a~assetclass,
         a~fixedassetdescription,
         a~assetadditionaldescription,
         a~lastretirementvaluedate,
         b~costcenter,
         b~validitystartdate,
         b~validityenddate,
         b~yy1_asset_fab AS assetuser
    FROM i_fixedasset WITH PRIVILEGED ACCESS AS a
    LEFT OUTER JOIN i_fixedassetassgmt WITH PRIVILEGED ACCESS AS b
                             ON a~companycode = b~companycode
                            AND a~masterfixedasset = b~masterfixedasset
                            AND a~fixedasset = b~fixedasset
   WHERE a~companycode IN @r_bukrs
     AND a~masterfixedasset IN @r_anln1
     AND a~assetclass IN @r_anlkl
     AND a~fixedassetdescription IN @r_txt50
     AND b~yy1_asset_fab IN @r_asset
    INTO TABLE @DATA(lt_fixedasset).

  LOOP AT lt_fixedasset INTO DATA(ls_fixedasset).
    CLEAR:ls_out.
    MOVE-CORRESPONDING ls_fixedasset TO ls_out.
    APPEND ls_out TO lt_out.
  ENDLOOP.


  o_resp-msgty = 'S'.


  "分页查询
  SORT lt_out BY companycode masterfixedasset fixedasset.
  DATA(lv_lines) =  lines( lt_out ).
  DATA(lv_totalpage) = ceil( CONV decfloat34( lv_lines / lv_pagesize ) ).
  DATA(begno) = ( lv_currpage - 1 ) * lv_pagesize + 1.
  DATA(endno) = lv_currpage * lv_pagesize .

  APPEND LINES OF lt_out FROM begno TO endno TO o_resp-res.

  IF  o_resp-res[] IS INITIAL.
    o_resp-msgtx = '查无数据'.
  ELSE.
    o_resp-count = lv_lines.
    o_resp-currpage  = lv_currpage.
    o_resp-totalpage = lv_totalpage.
    o_resp-msgtx = 'success'.
  ENDIF.

ENDFUNCTION.
