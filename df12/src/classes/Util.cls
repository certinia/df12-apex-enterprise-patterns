/**
 * Copyright (c) 2012, FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

public with sharing class Util 
{
	public static void applyDiscountV1(Opportunity opportunity, Decimal discountPercentage)
	{			
		// Calculate discount factor
		Decimal factor = calculateDiscountFactor(discountPercentage);
		if(opportunity.OpportunityLineItems.size()==0)
		{
			// Adjust the Amount on the Opportunity if no lines
			opportunity.Amount = opportunity.Amount * factor;
		}
		else
		{
			// Adjust UnitPrice of each line
			for(OpportunityLineItem line : opportunity.OpportunityLineItems)
				line.UnitPrice = line.UnitPrice * factor;
		}		
		// Update line items
		update opportunity.OpportunityLineItems;		
	}

	public static void applyDiscount(Opportunity opportunity, Decimal discountPercentage)
	{			
		// Calculate discount factor
		Decimal factor = calculateDiscountFactor(discountPercentage);
		if(opportunity.OpportunityLineItems.size()==0)
		{
			// Adjust the Amount on the Opportunity if no lines
			opportunity.Amount = opportunity.Amount * factor;
			update opportunity;
		}
		else
		{
			// ENH:1024. Adjust UnitPrice of each line according to Discount Type of Opportunity
			for(OpportunityLineItem line : opportunity.OpportunityLineItems)
			{
				// ENH:1024. Skip products that have not been approved for discounting
				if(opportunity.DiscountType__c == 'Approved Products')
					if(line.PricebookEntry.Product2.DiscountingApproved__c == false)
						continue;
				// Adjust UnitPrice
				line.UnitPrice = line.UnitPrice * factor;
			}
			update opportunity.OpportunityLineItems;		
		}		
	}
	
	public static Decimal calculateDiscountFactor(Decimal discountPercentage)
	{
		// Calculate discount factor
		Decimal discountProportion = discountPercentage==null ? 0 : discountPercentage / 100;
		Decimal factor = 1 - discountProportion;
		return factor;		
	}

	public static Id createInvoice(Opportunity opportunity)
	{
		return null;
	}
}