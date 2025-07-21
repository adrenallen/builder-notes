Inertia related stuff

# Form state 

## Inertia forms, reflecting prop updates
This is for components that are being filled from the inertia connection, data that is being provided at load, not async or self contained loads.

Essentially need to use refs to avoid infinite loops as the state will update from the save
```js
const { patch, setData, data, errors } = useForm<{
    stops: ShipmentStop[];
}>({
    stops: getSavedStops(),
});

const setDataRef = useRef(setData);

useEffect(() => {
    setDataRef.current({
        stops: getSavedStops(),
    });
}, [stops, getSavedStops]);
```

# Handling errors automatically into toasts

`bootstrap/app.php`

Add this into withExceptions
```php
->withExceptions(function (Exceptions $exceptions) {
        $exceptions->respond(function (Symfony\Component\HttpFoundation\Response $response, Throwable $exception, Request $request) {
            $isServerError = in_array($response->getStatusCode(), [500, 503], true);
            $isInertia = $request->headers->get('X-Inertia') === 'true';
            // When in an Inertia request, we don't want to show the default error modal
            if ($isServerError && $isInertia) {
                $errorMessage = 'An internal error occurred, please try again. If the problem persists, please contact support.';
                // In local environment let's show the actual exception class & message
                if (App::hasDebugModeEnabled()) {
                    $errorMessage .= sprintf("\n%s: %s", get_class($exception), $exception->getMessage());
                }
                return response()->json([
                    'error_message' => $errorMessage,
                ], $response->getStatusCode());
            }

            if ($response->getStatusCode() === 419) {
                return back()->with([
                    'flash.banner' => 'The page expired, please try again.',
                ]);
            }

            return $response;
        });
    })
```

Create a new hook `resources/js/hooks/useIenrtiaErrorHandler.ts`

```js
import { useToast } from '@/hooks/UseToast';
import { router } from '@inertiajs/react';
import { useEffect } from 'react';

export function useInertiaErrorHandler() {
    const { toast } = useToast();

    useEffect(() => {
        const removeEventListener = router.on('invalid', (event) => {
            const responseBody = event.detail.response?.data;
            if (responseBody?.error_message) {
                toast({
                    variant: 'destructive',
                    title: 'An error has occurred',
                    description: responseBody?.error_message,
                });
                event.preventDefault();
            }
        });

        // Cleanup the event listener on component unmount
        return () => {
            removeEventListener();
        };
    }, [toast]); // Add toast as a dependency
}
```

Inside each layout you use, put this as the first lin in the actual layout func

```js
useInertiaErrorHandler();
```
