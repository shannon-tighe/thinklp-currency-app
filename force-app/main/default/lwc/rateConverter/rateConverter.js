import { LightningElement, track } from 'lwc';
import getSupportedCurrencyCodes from '@salesforce/apex/RateConverterController.getSupportedCurrencyCodes';
import convertApex from '@salesforce/apex/RateConverterController.convert';

export default class RateConverter extends LightningElement {
    @track currencyOptions = [];
    amount = 1;
    baseCode = 'USD';
    quoteCode = 'EUR';
    rateDate = null;   // yyyy-mm-dd string
    isConverting = false;
    result = null;
    error = null;

    // Determines if there is a non-error result to display
    get hasResult() {
        return this.result !== null && this.error === null;
    }

    // Handlers to map UI data to the controller
    handleAmount = (e) => { this.amount = e.detail.value; };
    handleFrom   = (e) => { this.baseCode = e.detail.value; };
    handleTo     = (e) => { this.quoteCode = e.detail.value; };
    handleDate   = (e) => { this.rateDate = e.detail.value || null; };

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
            // Set defaults if available
            if (!codes || codes.length === 0) return;
            if (!codes.includes(this.baseCode)) this.baseCode = codes[0];
            if (!codes.includes(this.quoteCode)) this.quoteCode = (codes[1] || codes[0]);
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
        this.error = null;
        this.result = null;
        this.isConverting = true;

        convertApex({
            amount: Number(this.amount || 0),
            baseCode: this.baseCode,
            quoteCode: this.quoteCode,
            rateDate: this.rateDate ? new Date(this.rateDate) : null
        })
        .then(val => {
            this.result = this.formatNumber(val);
        })
        .catch(e => {
            this.error = this.normalizeError(e);
        })
        .finally(() => {
            this.isConverting = false;
        });
    };

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
