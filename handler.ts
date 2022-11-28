import { Handler } from 'aws-lambda'

/**
 * @description Defines a very basic Lambda handler which uses the utility functions defined here to return a response to the requestor based on the queryParams present on the request uri
 *              Original credit and thanks to Elvis Ciotti for creating the project that can be found here: https://elvisciotti.medium.com/lambda-function-on-aws-with-terraform-2a38f3053a06
 * @author Michael Stallings
 * 
 */

function shuffle(arr: Array<any>): Array<any> {
    let currentIndex = arr.length;
    let temporaryValue;
    let randomIndex;
    // Shuffle the quotes we're hardcoding into the lambda. Somewhat interesting approach (to me at least) where Elvis
    // swaps and increments within the following while loop. Worth noting from my perspective is we've set the variable 
    // currentIndex to the length of the array, which we will next see decremented and swapped, but of worth noting
    // that even though we're calling the variable currentIndex, we're initializing it to a value that will at first
    // be out of range. Again that is handled next, but interesting. 
    while (currentIndex !== 0) {
        // select a random index based on the array length. Using floor guards against our initial out-of-range condition
        randomIndex = Math.floor(Math.random() * currentIndex);         
        currentIndex--;         // decrement what has become our 'counter'
        // swap the current element (which should be the last element in the array) with the randomly selected one
        temporaryValue = arr[currentIndex];
        arr[currentIndex] = arr[randomIndex];
        arr[randomIndex] = temporaryValue;
    }

    return arr;
}

const QUOTE_ENTRIES = [
    '1: If you are not ashamed of what you were 1 year ago, then you have not improved much',
    '2: Success is determined by how well you manage failures',
    '3: The egg has a perfect shape, even if it\'s laid from the ass',
    '4: Those who know everything learn nothing',
    '5: Fuggit, Let\'s go to Amsterdam for New Years'
];

// TODO: Get types for aws lambda and remove the 'any' typing
function successResponse(event: any, data: any): any {
    return {
        statusCode: 200,
        body: JSON.stringify({
            data: data,
            event: event.queryStringParameters
        },
        null,
        2
        )
    };
}

function handleError(event: any, context: any): any {

    const eventString = JSON.stringify({
        event
    })
    const contextString = JSON.stringify({
        context
    })

    return {
        statusCode: 404,
        body: contextString,
        events: eventString 
    }
}

interface ResponseObject {
    statusCode: number
    body: string
}

// module.exports.handler = async (event: any): Handler<ResponseObject> => {

//     const action = event.queryStringParameters.action;
//     const limit = event.queryStringParameters.limit ? parseInt(event.queryStringParameters.limit) : 10;

//     if (action) {
//         switch (action) {
//             case 'random-quote':
//                 const gratitudeItems = shuffle(QUOTE_ENTRIES);
//                 return successResponse(event, gratitudeItems.slice(0, limit))
//             case 'todays-date':
//                 return successResponse(event, new Date())
//             default:
//                 return {
//                     statusCode: 404,
//                     body: "That action is not implemented"
//                 }
//         }
//     }
    
// }

export const handler: Handler<ResponseObject> = async (event: any, context: any) => {

    const action = event.queryStringParameters.action;
    const limit = event.queryStringParameters.limit ? parseInt(event.queryStringParameters.limit) : 10;

    if (action) {
        switch (action) {
            case 'random-quote':
                const gratitudeItems = shuffle(QUOTE_ENTRIES);
                return successResponse(event, gratitudeItems.slice(0, limit))
            case 'todays-date':
                return successResponse(event, new Date())
            default:
                return {
                    statusCode: 404,
                    body: "That action is not implemented"
                }
        }
    }
    return handleError(event, context)
    
}
