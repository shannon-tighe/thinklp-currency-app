import { LightningElement, track } from 'lwc';
import getSupportedCurrencyCodes from '@salesforce/apex/RateConverterController.getSupportedCurrencyCodes';
import convertApex from '@salesforce/apex/RateConverterController.convert';

export default class RateConverter extends LightningElement {
    @track currencyOptions = [];
    amount = 1;
    baseCode;
    quoteCode;
    rateDate = null;   // yyyy-mm-dd string
    isConverting = false;
    result = null;
    error = null;

    // Determines whether to display the converted amount
    get hasConvertedAmount() {
        return this.result && this.result.convertedAmount && !this.error;
    }
    // Determines whether to display the exchange rate
    get hasRate() {
        return this.result && this.result.rate && !this.error;
    }
    // Determines whether the convert method has it's required parameters
    get hasRequiredParams() {
        return this.amount && this.amount > 0 && this.baseCode && this.quoteCode;
    }

    // Event handlers to map UI input to the controller
    handleAmount = (e) => {
        this.amount = e.detail.value;
        this.resetResult();
    };
    handleFrom = (e) => {
        this.baseCode = e.detail.value;
        this.resetResult();
    };
    handleTo = (e) => {
        this.quoteCode = e.detail.value;
        this.resetResult();
    };
    handleDate = (e) => {
        this.rateDate = e.detail.value || null;
        this.resetResult();
    };

    /**
     * Fetch data imperatively
     * Future - switch to wire if filters (i.e. reactive props) are added
     */
    connectedCallback() {
        getSupportedCurrencyCodes()
        .then(codes => {
            console.log('Codes:\n', codes);
            this.currencyOptions = (codes || []).map(c => ({ 
                label: c.name + ' (' + c.code + ')',
                value: c.code
            }));
        })
        .catch(e => {
            this.error = this.normalizeError(e);
        });
    }

    // Swaps which currency is the Base ("from") and which is Quote ("to")
    swapCodes = () => {
        const tmp = this.baseCode;
        this.baseCode = this.quoteCode;
        this.quoteCode = tmp;
    };

    convert = () => {
        // Clear existing results/errors and reveal "Converting..."
        this.resetResult();
        this.isConverting = true;

        // Inform User if parameters are invalid
        if(!this.hasRequiredParams) {
            this.error = 'Please enter a valid amount, base, and quote currency.';
            this.isConverting = false;
        }

        // Perform the conversion
        convertApex({
            amount: Number(this.amount || 0),
            baseCode: this.baseCode,
            quoteCode: this.quoteCode,
            rateDate: this.rateDate ? new Date(this.rateDate) : null
        })
        .then(val => {
            this.result = val;
            // Format numbers for display
            if(this.result?.convertedAmount) this.result.convertedAmount = this.formatNumber(this.result.convertedAmount);
            if(this.result?.rate) this.result.rate = this.formatNumber(this.result.rate);
        })
        .catch(e => {
            this.error = this.normalizeError(e);
            this.isConverting = false;
        })
        .finally(() => {
            this.isConverting = false;
        });
    };

    resetResult() {
        this.error = null;
        this.result = null;
    }

    formatNumber(n) {
        // Avoid specifying locales; keep it simple/neutral
        try {
            return new Intl.NumberFormat(undefined, { maximumFractionDigits: 6 }).format(n);
        } catch {
            return String(n);
        }
    }

    normalizeError(e) {
        const msg =
        e?.body?.message || e?.message || e?.body?.exceptionType || 'Unexpected error';
        return msg;
    }
}
