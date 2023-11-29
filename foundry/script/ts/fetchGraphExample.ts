import { ExampleQueryDocument, ExampleQueryQuery, execute } from '.graphclient'
export async function fetchPositions() {
    console.log('Fetching positions...')
    try {
        const result: ExampleQueryQuery = await execute(ExampleQueryDocument, {})
        console.log(JSON.stringify(result, null, 2))
    } catch (error) {
        console.error(error)
    }
}

fetchPositions()
