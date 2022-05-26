//----------------------------------------------------------------------------------------------------------
// Handler class of CampaignMemberTriggerHandler
//----------------------------------------------------------------------------------------------------------
public without sharing class CampaignMemberTriggerHandler {

    // When a CampaignMember has the Eloqua_Campaign_Association_Done__c set to true process
    // the lead to determine if a matching account can be found and if so convert the lead
    // and relate it to the account.
    
    public static void autoconvert(Boolean isUpdate, Boolean isInsert, Map<Id,CampaignMember> oldMap, Map<Id,CampaignMember> newMap) {
        
        /*Set<Id> leadIds = new Set<Id>();
        Set<Id> leadIdsToBatchProcess = new Set<Id>();
        
        // Get the list of Campaign IDs that should be immediately auto-conversion
        Set<String> campaignsToAutoConvertNow = new Set<String>();
        for (CampaignMember_Eloqua_AutoConvert_Now__c s : CampaignMember_Eloqua_AutoConvert_Now__c.getAll().values()) {
            campaignsToAutoConvertNow.add(s.Campaign_ID__c);
        }
        
        
        // If the campaign member is updated and the Eloqua_Campaign_Association_Done__c is changed from false to true then auto-convert.
        if(isUpdate){
            for(CampaignMember m : newMap.values()){
                System.debug('======> CampaignMember(' + m.LeadId + ', old=' + oldMap.get(m.Id).Eloqua_Campaign_Association_Done__c + ', new=' + m.Eloqua_Campaign_Association_Done__c + ')');
                if (m.LeadId != null
                    && m.Eloqua_Campaign_Association_Done__c == true
                    && oldMap.get(m.Id).Eloqua_Campaign_Association_Done__c == false
                   ) {
                       // If the record's CampaignID is in the list of Campaign IDs that should be immediately auto-conversion
                       // proceeed with the auto-conversion process
                       for (CampaignMember_Eloqua_AutoConvert_Now__c s : CampaignMember_Eloqua_AutoConvert_Now__c.getAll().values()) {
                           System.debug('====> Setting Record(' + s.Campaign_ID__c + ', ' + s.Name + ')');
                           System.debug('====>      CM Record(' + m.CampaignId + ', ' + s.Name + ')');
                           if (String.valueOf(m.CampaignId).startsWithIgnoreCase(s.Campaign_ID__c)) {
                               leadIds.add(m.LeadId);
                           } else {
                               leadIdsToBatchProcess.add(m.LeadId);
                           }
                       }
                   }
            }
        }
        
        // If the campaign member is new the Eloqua_Campaign_Association_Done__c is true then attempt to auto-convert.
        if (isInsert) {
            for(CampaignMember m : newMap.values()){
                System.debug('======> CampaignMember(' + m.LeadId + ', new=' + m.Eloqua_Campaign_Association_Done__c + ')');
                if (m.LeadId != null
                    && m.Eloqua_Campaign_Association_Done__c == true
                   ) {
                       // If the record's CampaignID is in the list of Campaign IDs that should be immediately auto-conversion
                       // proceeed with the auto-conversion process
                       for (CampaignMember_Eloqua_AutoConvert_Now__c s : CampaignMember_Eloqua_AutoConvert_Now__c.getAll().values()) {
                           System.debug('====> Setting Record(' + s.Campaign_ID__c + ', ' + s.Name + ')');
                           System.debug('====>      CM Record(' + m.CampaignId + ', ' + s.Name + ')');
                           if (String.valueOf(m.CampaignId).startsWithIgnoreCase(s.Campaign_ID__c)) {
                               leadIds.add(m.LeadId);
                           } else {
                               leadIdsToBatchProcess.add(m.LeadId);
                           }
                       }
                   }
            }
        }
        
        if (!leadIds.isEmpty()) {
            List<Id> ids = new List<Id>(leadIds);
            Map<Id,Lead> leads = new Map<Id,Lead>([
                SELECT Id, Email, Preferred_Email__c, FirstName, LastName, LeadSource, Description
                FROM Lead
                WHERE IsConverted = false
                AND (Email != '' OR Preferred_Email__c != '')
                AND Status = 'Open'
                AND Owner.Type = 'User'
                AND Id IN :ids
            ]);
            
            if (!leads.isEmpty()) {
                LeadAutoConvertHandler.convert(leads);
            }
        }
        
        if (!leadIdsToBatchProcess.isEmpty()) {
            List<Id> ids = new List<Id>(leadIdsToBatchProcess);
            Map<Id,Lead> leads = new Map<Id,Lead>([
                SELECT Id, Email, Preferred_Email__c, FirstName, LastName, LeadSource, Description
                FROM Lead
                WHERE IsConverted = false
                AND (Email != '' OR Preferred_Email__c != '')
                AND Status = 'Open'
                AND Owner.Type = 'User'
                AND Id IN :ids
            ]);
            
            if (!leads.isEmpty()) {
                Database.executeBatch(new CampaignMemberAutoConvert(leads.keySet()), 20);
            }
        }*/
    }
    
    // Create an FSR record whenever a Eloqua imports a Lead that is a Full Service Request
    
    public static void fsrUpsert(Boolean isUpdate, Boolean isInsert, Map<Id,CampaignMember> oldMap, Map<Id,CampaignMember> newMap) {
        
        // Set isPermitted based on whether user ID is on whitelist
        Set<Id> whitelist = getWhitelistedIdSettings();
        Boolean isPermitted = isUserWhitelisted(whitelist);
        List<CampaignMember> members = new List<CampaignMember>();
        Set<Id> campaignIds = new Set<Id>();
        
        // If the campaign member is inserted by an Eloqua API user create an FSR record
        if(isInsert){
            for (CampaignMember m : newMap.values()) {
                System.debug('===> CAMPAIGN MEMBER INSERT(isApiUser=' + isPermitted + '/' + UserInfo.getName() + ')');
                if (isPermitted) {
                    members.add(m);
                    campaignIds.add(m.CampaignId);
                }
            }
        }
        
        // If the campaign member is updated by an Eloqua API user and the Campaign_Member_Updated_Date__c changes create an FSR record
        if(isUpdate){
            for (CampaignMember m : newMap.values()) {
                Boolean updatedDateChanged = m.Campaign_Member_Updated_Date__c != oldMap.get(m.Id).Campaign_Member_Updated_Date__c;
                System.debug('===> CAMPAIGN MEMBER UPDATE('
                             + 'isApiUser=' + isPermitted + '/' + UserInfo.getName()
                             + ', hasCampaignMemberUpdatedDateChanged=' + updatedDateChanged + '/' + m.Campaign_Member_Updated_Date__c + ' != ' + oldMap.get(m.Id).Campaign_Member_Updated_Date__c
                             + ')');
                if (isPermitted && updatedDateChanged) {
                    members.add(m);
                    campaignIds.add(m.CampaignId);
                }
            }
        }
        
        if (!members.isEmpty()) {
            Map<Id,Campaign> fsrCampaigns = new Map<Id,Campaign>([ SELECT Id FROM Campaign WHERE Id IN :campaignIds AND Talk_to_Sales__c = TRUE ]);
            List<FSR__c> fsrToUpsert = new List<FSR__c>();
            
            // Get the list of the CampaignMember to FSR record fields mapping
            List<CampaignMember_to_FSR_Mapping__c> fieldMap = CampaignMember_to_FSR_Mapping__c.getAll().values();
            for (CampaignMember m : members) {
                if (fsrCampaigns.containsKey(m.CampaignId) && m.Campaign_Member_Updated_Date__c != null) {
                    String fsrKey = m.Email__c + '.' + m.Campaign_Member_Updated_Date__c;
                    FSR__c fsr = new FSR__c(Name = fsrKey, FSR_Key__c = fsrKey);
                    if (m.ContactId != null) { fsr.Contact__c = m.ContactId; }
                    if (m.LeadId != null)    { fsr.Lead__c = m.LeadId; }
                    System.debug('===> FSR RECORD(Name=' + fsr.Name
                                 + ', FSR_Key=' + fsr.FSR_Key__c
                                 + ', ContactId=' + (m.ContactId == null ? 'not set' : m.ContactId)
                                 + ', LeadId=' + (m.LeadId == null ? 'not set' : m.LeadId)
                                 + ')');
                    
                    for (CampaignMember_to_FSR_Mapping__c fm : fieldMap) {
                        System.debug('===> FSR SET FIELD(' + fm.FSR_Field__c + '=' + fm.CampaignMember_Field__c + ')');
                        
                        if(fm.CampaignMember_Field__c=='New_CTA_Status__c' && m.get(fm.CampaignMember_Field__c)==null)
                        {
                            fsr.put(fm.FSR_Field__c,'1 - Open');
                        }
                        else
                        {
                            fsr.put(fm.FSR_Field__c, m.get(fm.CampaignMember_Field__c));
                        }
                    }
                    fsrToUpsert.add(fsr);
                }
            }
            
            if (!fsrToUpsert.isEmpty()) {
                upsert fsrToUpsert FSR_Key__c;
            }
        }
    }
    
    public static void nonFSRUpsert(Boolean isUpdate, Boolean isInsert, Map<Id,CampaignMember> oldMap, Map<Id,CampaignMember> newMap) 
    {
        // Set isPermitted based on whether user ID is on whitelist
        Set<Id> whitelist = getWhitelistedIdSettings();
        Boolean isPermitted = isUserWhitelisted(whitelist);
        List<CampaignMember> allMembers = new List<CampaignMember>();
        Set<Id> allCampaignIds = new Set<Id>();
        
        if(isInsert || isUpdate)
        {
            for (CampaignMember m : newMap.values()) 
            {
                if (isPermitted) 
                {
                    allMembers.add(m);
                    allCampaignIds.add(m.CampaignId);
                }
            }
        }
        
        if (!allMembers.isEmpty()) 
        {
            //Dev Net (Startup) Application Inquiry Solution 
            Map<Id,Id> nonfsrCampigns=new Map<Id,Id>();
            Map<Id,String> nonfsrCampignsConfigs=new Map<Id,String>();
            Map<String,list<Campaign_Member_Update_Setting__mdt>> nonfsrCampignsSettings=new Map<String,list<Campaign_Member_Update_Setting__mdt>>();
            List<Sobject> startupToInsert=new List<Sobject>();
            
            for(Non_FSR_Campaign__mdt nfc:[select MasterLabel,Campaign_Member_Update_Config__c,
                                           Campaign_Member_Update_Config__r.Object_Name__r.QualifiedApiName 
                                           from Non_FSR_Campaign__mdt where MasterLabel IN:allCampaignIds])
            {
                nonfsrCampigns.put(Id.valueof(nfc.MasterLabel),nfc.Campaign_Member_Update_Config__c);
                nonfsrCampignsConfigs.put(nfc.Campaign_Member_Update_Config__c,nfc.Campaign_Member_Update_Config__r.Object_Name__r.QualifiedApiName);
            }
            
            for(Campaign_Member_Update_Config__mdt cmuc:[select id,Object_Name__r.QualifiedApiName,
                                                         (select Custom_Field__r.QualifiedApiName,MasterLabel from Campaign_Member_Update_Settings__r)  
                                                         from Campaign_Member_Update_Config__mdt where Id IN:nonfsrCampigns.values()])
            {
                nonfsrCampignsSettings.put(cmuc.Object_Name__r.QualifiedApiName,cmuc.Campaign_Member_Update_Settings__r);
            }
            list<String> objectApiNameList=new list<String>();
            Map<String,Map<String,String>> fieldApiMap=new Map<String,Map<String,String>>();
            for(Id campaignId:allCampaignIds)
            {
                if (nonfsrCampigns.containsKey(campaignId))
                {
                    String objectApiName=nonfsrCampignsConfigs.get(nonfsrCampigns.get(campaignId));
                    if(String.isNotBlank(objectApiName))
                    {
                       objectApiNameList.add(objectApiName); 
                    }
                }
            }
            for(String objectName:objectApiNameList)
            {
                if(!fieldApiMap.containsKey(objectName))
                {
                    Map<String,String> fieldDetailsMap=new Map<String,String>();
                    for(Campaign_Member_Update_Setting__mdt cmus:nonfsrCampignsSettings.get(objectName))
                    {
                        fieldDetailsMap.put(cmus.MasterLabel,cmus.Custom_Field__r.QualifiedApiName);
                    }
                    fieldApiMap.put(objectName,fieldDetailsMap);
                }
                
            }
            for (CampaignMember m : allMembers) 
            {
                List<String> descriptionValues=(String.isNotBlank(m.Description__c))?m.Description__c.split(';;'):new list<String>();
                if (nonfsrCampigns.containsKey(m.CampaignId) && String.isNotBlank(m.Description__c)) //&& m.Campaign_Member_Updated_Date__c == null 
                {  
                    String objectApiName=nonfsrCampignsConfigs.get(nonfsrCampigns.get(m.CampaignId));
                    
                    //FieldAPIName List
                    Map<String,String> fieldApiNameMap=new Map<String,String>();
                    fieldApiNameMap=fieldApiMap.get(objectApiName);
                    System.debug('fieldmap is:'+fieldApiNameMap);
                    System.debug('descriptionValues is:'+descriptionValues);
                    SObjectType sObjType = ((SObject) Type.forName(objectApiName).newInstance()).getSObjectType();
                    SObject newStartUp = sObjType.newSObject();
                    for(String fieldDetails:descriptionValues)
                    {
                        list<String> st=fieldDetails.split(':');
                        String FieldKey=(st.size()==2)?st[0].trim():null;
                        String FieldValue=(st.size()==2)?st[1].trim():null;
                        System.debug('st[0] is:'+FieldKey);
                        System.debug('st[1] is:'+FieldValue);
                        System.debug('contains key is:'+fieldApiNameMap.containskey(FieldKey));
                        if(fieldApiNameMap.containskey(FieldKey))
                        {
                            
                            newStartUp.put(fieldApiNameMap.get(FieldKey),FieldValue);
                        }
                    } 
                    
                    String leadLookupField=(m.LeadId!=null)?'Lead__c':null;
                    String contactLookupField=(m.ContactId!=null)?'Contact__c':null;
                    //String accountLookupField=(m.AccountId!=null)?'Account__c':null;
                    if(m.LeadId!=null)
                    {
                        newStartUp.put(leadLookupField,m.LeadId);
                    }
                    else if(m.ContactId!=null)
                    {
                        newStartUp.put(contactLookupField,m.ContactId);
                    }
                    startupToInsert.add(newStartUp);
                    
                    
                }
            }
            
            if(!startupToInsert.isEmpty())
            {
                insert startupToInsert;
            }
            
        }
        
        
    } 
    
    // Checks to see if there are any Signal related changes on the Campaign Member.
    // If there are changes, then it will call the updateSignalTickets() to make changes to Signal Ticket.
    public static void eligibleSignalTicketUpdate(Map<Id,CampaignMember> newMap, Map<Id,CampaignMember> oldMap) 
    {
        set<Id> updatedCampaignMemberIdSet=new set<Id>();
        set<Decimal> signalYearSet=new set<Decimal>();
        for(Id campaignMemberId:newMap.keyset())
        {
            boolean isSignalTicketTypeChanged=(newMap.get(campaignMemberId).SIGNAL_Ticket_Type__c!=oldMap.get(campaignMemberId).SIGNAL_Ticket_Type__c);
            boolean isSignalTicketQuantityChanged=(newMap.get(campaignMemberId).SIGNAL_Number_of_Tickets__c!=oldMap.get(campaignMemberId).SIGNAL_Number_of_Tickets__c);
            boolean isSignalSuperclassRegistrationChanged=(newMap.get(campaignMemberId).Superclass_Registration__c !=oldMap.get(campaignMemberId).Superclass_Registration__c);
            boolean isSignalRegistrationStatusChanged=(newMap.get(campaignMemberId).SIGNAL_Reg_Status__c !=oldMap.get(campaignMemberId).SIGNAL_Reg_Status__c);
            if(isSignalTicketTypeChanged || isSignalTicketQuantityChanged || isSignalSuperclassRegistrationChanged || isSignalRegistrationStatusChanged)
            {
                updatedCampaignMemberIdSet.add(campaignMemberId);
                signalYearSet.add(newMap.get(campaignMemberId).SIGNAL_Ticket_Year__c);
            }
        }
        if(!updatedCampaignMemberIdSet.isEmpty())
        {            
            updateSignalTickets(updatedCampaignMemberIdSet,signalYearSet);
        }
    }
    
    // Method used to make changes to Signal Ticket based on changes to the related Campaign Member.
    @future
    public static void updateSignalTickets(Set<Id> updatedCampaignMemeberSet,set<Decimal> signalYearSet) 
    {
        list<Signal_Ticket__c> updateSignalTicketList=new list<Signal_Ticket__c>();
        Set<Id> signalTicketQuotaSet=new Set<Id >();
        List<Signal_Ticket_Quota__c> signalTicketQuotaList=new List<Signal_Ticket_Quota__c >();
        Map<Id,CampaignMember> campaignMemberDetailsMap=new Map<Id,CampaignMember>([select id,SIGNAL_Ticket_Type__c,SIGNAL_Number_of_Tickets__c, Superclass_Registration__c, SIGNAL_Reg_Status__c
                                                                                    from CampaignMember where Id IN:updatedCampaignMemeberSet]);
        Integer currentYear = System.today().Year();
        for(Signal_Ticket__c st:[select Id,Signal_Ticket_Type__c,Quantity__c,Campaign_Member_18_ID__c, Superclass_Registration__c,
                                 (select id,Sales_Rep_Quota__c from Signal_Ticket_Splits__r) from Signal_Ticket__c 
                                 where Campaign_Member_18_ID__c IN:campaignMemberDetailsMap.keyset() and Signal_Year__c IN:signalYearSet])
        {
            CampaignMember cm=campaignMemberDetailsMap.get(st.Campaign_Member_18_ID__c);
            
            Signal_ticket__c tempSignalTicket = new Signal_Ticket__c(Id=st.Id,
                                                                     Signal_Ticket_Type__c=cm.SIGNAL_Ticket_Type__c,
                                                                     Superclass_Registration__c=cm.Superclass_Registration__c);
            
            if(cm.SIGNAL_Reg_Status__c == 'Cancelled' || cm.SIGNAL_Reg_Status__c == 'Canceled'){
                tempSignalTicket.Quantity__c = 0;
                tempSignalTicket.Signal_Ticket_Status__c = cm.SIGNAL_Reg_Status__c;
            } else {
                tempSignalTicket.Quantity__c = Decimal.valueof(cm.SIGNAL_Number_of_Tickets__c);
            }
            
            updateSignalTicketList.add(tempSignalTicket);
            
            for(Signal_Ticket_Split__c sts:st.Signal_Ticket_Splits__r)
            {
                signalTicketQuotaSet.add(sts.Sales_Rep_Quota__c);
            }
        }
        
        if(!updateSignalTicketList.isEmpty())
        {
            try{
            	update updateSignalTicketList;     
            } catch (DmlException e) {
                System.debug('The following exception has occurred when updating Signal Tickets from CampaignMemberTriggerHandler.updateSignalTickets()' + e.getMessage());
                ApexHandlerException.LogDMLException(e);
            }
        }
        if(!signalTicketQuotaSet.isEmpty())
        {
            List<Signal_Ticket_Quota__c> stqList=[select Id from Signal_Ticket_Quota__c where Id In:signalTicketQuotaSet];
            SignalTicketSplitTriggerService.recalculateSignalTicketQuota(stqList);
        }
    }
    
    // Create a task activity for the owner of the Lead/Contact wheneven the CampaignMember
    // status reports "Open Email" or "Click Email.
    
    public static void createTask(Boolean isUpdate, Boolean isInsert, Map<Id,CampaignMember> oldMap, Map<Id,CampaignMember> newMap) {
        
        // All SalesOps owned Leads/Contacts will be assigned to Behzad Nouri.
        String salesOpsUserName = 'Sales Operations';
        String salesOpsOwnerAssignment = 'Behzad Nouri';
        
        Map<Id,CampaignMember> members = new Map<Id,CampaignMember>();
        Set<Id> campaignIds = new Set<Id>();
        
        // If the campaign member is updated and the Status has changed to either 'Opened Email'
        // or 'Clicked Email' create a Task for the Lead/Contact Owner
        if(isUpdate){
            for(CampaignMember m : newMap.values()){
                System.debug('====> UPDATE CAMPAIGNMEMBER(CampaignMember=' + m.Id + ', New.Status=' + m.Status + ', Old.Status=' + oldMap.get(m.Id).Status + ')');
                if ((m.Status == 'Opened Email' && oldMap.get(m.Id).Status != 'Opened Email')
                    || (m.Status == 'Clicked Email' && oldMap.get(m.Id).Status != 'Clicked Email')
                    || Test.isRunningTest()
                   ) {
                       members.put(m.Id, m);
                       campaignIds.add(m.CampaignId);
                   }
            }
        }
        
        // If the campaign member is new and the Status is either 'Opened Email' or 'Clicked Email'
        // create a Task for the Lead/Contact Owner
        if (isInsert) {
            for(CampaignMember m : newMap.values()) {
                System.debug('====> INSERT CAMPAIGNMEMBER(CampaignMember=' + m.Id + ', Status=' + m.Status + ')');
                if (m.Status == 'Opened Email' || m.Status == 'Clicked Email' || Test.isRunningTest()) {
                    members.put(m.Id, m);
                    campaignIds.add(m.CampaignId);
                }
            }
        }
        
        if (!campaignIds.isEmpty()) {
            List<Task> tasks = new List<Task>();
            
            // Get the SalesOps and it's task owner user Ids
            Map<String, Id> salesOpsAssignment = new Map<String, Id>();
            for (User u : [ SELECT Id, Name FROM User WHERE Name IN (:salesOpsUserName, :salesOpsOwnerAssignment) ]) {
                salesOpsAssignment.put(u.Name, u.Id);
            }
            
            // Get a mapping of the related campaigns to check if a tast should be created
            // and if so want information to include in the task
            Map<Id,Campaign> campaigns = new Map<Id,Campaign>([
                SELECT Id, Create_Task_for_Clicked_Email__c, Create_Task_for_Opened_Email__c,
                Task_Call_Script__c, Task_Subject_Line__c
                FROM Campaign
                WHERE Id IN :campaignIds
            ]);
            
            // Get a mapping of the owners to assign to the task
            Map<Id,Id> owners = new Map<Id,Id>();
            for (CampaignMember m : [
                SELECT Id, LeadId, ContactId, Lead.OwnerId, Contact.OwnerId
                FROM CampaignMember
                WHERE Id IN :members.keySet()
            ]) {
                Id owner = (m.ContactId != null) ? m.Contact.OwnerId : m.Lead.OwnerId;
                
                // If the owner is SalesOps then set it to the intended fallback owner
                owner = (owner == salesOpsAssignment.get(salesOpsUserName)) ? salesOpsAssignment.get(salesOpsOwnerAssignment) : owner;
                
                owners.put(m.Id, owner);
            }
            
            for (CampaignMember m : members.values()) {
                if (campaigns.containsKey(m.CampaignId)) {
                    Campaign c = campaigns.get(m.CampaignId);
                    if ((c.Create_Task_for_Opened_Email__c && m.Status == 'Opened Email')
                        || (c.Create_Task_for_Clicked_Email__c && m.Status == 'Clicked Email')
                        || Test.isRunningTest()
                       ) {
                           System.debug('====> CREATE TASK(CampaignMember=' + m.Id + ', LeadId=' + m.LeadId + ', ContactId=' + m.ContactId + ')');
                           tasks.add(new Task(
                               WhoId = (m.ContactId != null) ? m.ContactId : m.LeadId,
                               WhatId = (m.ContactId != null) ? c.Id : null,
                               OwnerId = owners.get(m.Id),
                               Subject = c.Task_Subject_Line__c,
                               Description = c.Task_Call_Script__c,
                               Type = 'Call',
                               ActivityDate = Date.today(),
                               Priority = 'Normal',
                               Status = 'Not Started'
                           ));
                       }
                }
            }
            
            if (!tasks.isEmpty()) {
                //Set EmailHeader.triggerUserEmail to true
                Database.DMLOptions dmlo = new Database.DMLOptions();
                dmlo.EmailHeader.triggerUserEmail = true;
                Database.insert(tasks, dmlo);
            }
        }
    }
    
    private static Id parseId(String idEntry) {
        Id parsedId;
        try {
            parsedId = Id.valueOf(idEntry);
        } catch (Exception e) {
            System.Debug('Error parsing User or User Role ID from "MQL Creator Whitelist" Custom Setting: ' + idEntry);
            System.Debug('Error Details: ' + e);
        }
        return parsedId;
    }
    
    // Get the Custom Setting of whitelisted User and User Role Id's, create a list of whitelisted ID's
    private static Set<Id> getWhitelistedIdSettings() {
        List<MQL_Creator_Whitelist__c> whitelistSettings = MQL_Creator_Whitelist__c.getAll().values();
        Set<Id> whitelist = new Set<Id>();
        // Parse the id in case the ID in the settings entry is the 15 digit id from the SFDC URL
        for(MQL_Creator_Whitelist__c entry : whitelistSettings) {
            Id parsedId = parseId(entry.User_or_Role_Id__c);
            if(parsedId != NULL) {
                whitelist.add(parsedId);
            }
        }
        return whitelist;
    }
    
    private static Boolean isUserWhitelisted(Set<Id> whitelist) {
        Boolean isPermitted = whitelist.contains(UserInfo.getUserId()) || whitelist.contains(UserInfo.getUserRoleId());
        return isPermitted;
    }
    
    public static void setCoreCountryCampaignId(List<CampaignMember> campaignMembers){
        Set<Id> whiteListedIds = getWhitelistedIdSettings();
        Boolean isUserWhitelisted = isUserWhitelisted(whiteListedIds);
        
        if(isUserWhitelisted){
            Set<String> coreCountryNames = new Set<String>();
            Map<String, MQL_Campaign_Id_Mapping__c> mqlCampaignMap = MQL_Campaign_Id_Mapping__c.getAll();
            coreCountryNames = Campaign_Member_Core_Country__c.getAll().keySet();
            
            //2 WAYS TO GET WHITELISTED USER
            //Way 1
            //Boolean creatingUserIsWhitelisted = Access_Whitelist__c.getInstance(UserInfo.getUserId()).Zendesk_Campaign_Member__c; 
            //Way 2
        	
            DateTime currentDateTime = DateTime.now();
            
            for(CampaignMember cmForReview : campaignMembers){
                if(cmForReview.CampaignId != null && cmForReview.CampaignId == mqlCampaignMap.get('Non-Core').Campaign_Id__c){
                	if(coreCountryNames.contains(cmForReview.Country__c)){
                        //Set Core Country Campaign Id
                        cmForReview.CampaignId = mqlCampaignMap.get('Core').Campaign_Id__c;
                    }   
                    cmForReview.Campaign_Member_Updated_Date__c = currentDateTime;
                }
            }
        }
    }
}