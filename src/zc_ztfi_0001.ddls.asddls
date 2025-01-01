@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
define root view entity ZC_ZTFI_0001
  provider contract TRANSACTIONAL_QUERY
  as projection on ZR_ZTFI_0001
{
  key Bankn,
  Bukrs,
  Hbkid,
  Hktid,
  Prctr,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt
  
}
